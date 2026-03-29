import Foundation
import NaturalLanguage
@preconcurrency import Translation

struct TranslationResult {
    let sourceLanguageIdentifier: String
    let sourceLanguageDisplayName: String
    let translatedText: String
}

enum TranslationServiceError: LocalizedError {
    case emptyInput
    case unableToIdentifyLanguage
    case unsupportedSystem
    case unsupportedLanguagePair(source: String, target: String)
    case languageModelsMissing(
        source: String,
        target: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    )

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "Enter some text to translate."
        case .unableToIdentifyLanguage:
            return "Unable to identify the source language."
        case .unsupportedSystem:
            return "Translation requires a newer macOS version."
        case .unsupportedLanguagePair(let source, let target):
            return "Unsupported translation pair: \(source) -> \(target)."
        case .languageModelsMissing(let source, let target, _, _):
            return "Missing Apple translation models for \(source) -> \(target). Install them in System Settings > General > Language & Region > Translation Languages."
        }
    }
}

actor TranslationService {
    private enum Keys {
        static let confirmedInstalledPairs = "confirmed_installed_pairs"
    }

    private let defaults: UserDefaults
    private var confirmedInstalledPairs: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedPairs = defaults.array(forKey: Keys.confirmedInstalledPairs) as? [String] ?? []
        self.confirmedInstalledPairs = Set(storedPairs)
    }

    func translate(
        _ text: String,
        sourceLanguage: TranslationLanguage?,
        targetLanguage: TranslationLanguage
    ) async throws -> TranslationResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TranslationServiceError.emptyInput
        }

        let resolvedSource = try sourceLanguage?.localeLanguage ?? detectSourceLanguage(in: trimmed)
        let resolvedTarget = targetLanguage.localeLanguage

        if resolvedSource.minimalIdentifier == resolvedTarget.minimalIdentifier {
            return TranslationResult(
                sourceLanguageIdentifier: resolvedSource.minimalIdentifier,
                sourceLanguageDisplayName: localizedLanguageName(for: resolvedSource),
                translatedText: trimmed
            )
        }

        guard #available(macOS 26.0, *) else {
            throw TranslationServiceError.unsupportedSystem
        }

        let availability = LanguageAvailability()
        let initialStatus = await availability.status(from: resolvedSource, to: resolvedTarget)
        Diagnostics.info(
            "Translation availability status=\(describe(initialStatus)) from=\(resolvedSource.minimalIdentifier) to=\(resolvedTarget.minimalIdentifier)"
        )

        switch initialStatus {
        case .installed, .supported:
            break
        case .unsupported:
            throw TranslationServiceError.unsupportedLanguagePair(
                source: localizedLanguageName(for: resolvedSource),
                target: localizedLanguageName(for: resolvedTarget)
            )
        @unknown default:
            break
        }

        do {
            let translated = try await translateUsingSessionWithRetry(
                text: trimmed,
                sourceLanguage: resolvedSource,
                targetLanguage: resolvedTarget
            )
            rememberInstalledPair(resolvedSource, resolvedTarget)
            return TranslationResult(
                sourceLanguageIdentifier: resolvedSource.minimalIdentifier,
                sourceLanguageDisplayName: localizedLanguageName(for: resolvedSource),
                translatedText: translated
            )
        } catch let translationError as TranslationError {
            switch translationError {
            case .notInstalled:
                let recovered = try await recoverFromNotInstalled(
                    text: trimmed,
                    sourceLanguage: resolvedSource,
                    targetLanguage: resolvedTarget
                )
                return TranslationResult(
                    sourceLanguageIdentifier: recovered.source.minimalIdentifier,
                    sourceLanguageDisplayName: localizedLanguageName(for: recovered.source),
                    translatedText: recovered.text
                )
            default:
                throw translationError
            }
        }
    }

    @available(macOS 26.0, *)
    private func translateUsingSession(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async throws -> String {
        let session = TranslationSession(
            installedSource: sourceLanguage,
            target: targetLanguage
        )
        try await session.prepareTranslation()
        let response = try await session.translate(text)
        return response.targetText
    }

    @available(macOS 26.0, *)
    private func translateUsingSessionWithRetry(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language,
        maxAttempts: Int = 3
    ) async throws -> String {
        var attempt = 1
        while true {
            do {
                return try await translateUsingSession(
                    text: text,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            } catch let translationError as TranslationError {
                switch translationError {
                case .notInstalled where attempt < maxAttempts:
                    attempt += 1
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    continue
                default:
                    throw translationError
                }
            }
        }
    }

    @available(macOS 26.0, *)
    private func recoverFromNotInstalled(
        text: String,
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async throws -> (source: Locale.Language, text: String) {
        let availability = LanguageAvailability()
        let refreshedStatus = await availability.status(from: sourceLanguage, to: targetLanguage)

        let normalizedSource = normalize(sourceLanguage)
        let normalizedTarget = normalize(targetLanguage)
        let hasNormalizedVariant =
            normalizedSource.minimalIdentifier != sourceLanguage.minimalIdentifier ||
            normalizedTarget.minimalIdentifier != targetLanguage.minimalIdentifier

        if let installedVariantPair = await findInstalledVariantPair(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ) {
            let translated = try await translateUsingSessionWithRetry(
                text: text,
                sourceLanguage: installedVariantPair.0,
                targetLanguage: installedVariantPair.1
            )
            rememberInstalledPair(sourceLanguage, targetLanguage)
            rememberInstalledPair(installedVariantPair.0, installedVariantPair.1)
            return (installedVariantPair.0, translated)
        }

        switch refreshedStatus {
        case .unsupported:
            throw TranslationServiceError.unsupportedLanguagePair(
                source: localizedLanguageName(for: sourceLanguage),
                target: localizedLanguageName(for: targetLanguage)
            )
        case .installed:
            let translated = try await translateUsingSessionWithRetry(
                text: text,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
            rememberInstalledPair(sourceLanguage, targetLanguage)
            return (sourceLanguage, translated)
        case .supported:
            if hasNormalizedVariant {
                do {
                    let translated = try await translateUsingSessionWithRetry(
                        text: text,
                        sourceLanguage: normalizedSource,
                        targetLanguage: normalizedTarget
                    )
                    rememberInstalledPair(sourceLanguage, targetLanguage)
                    rememberInstalledPair(normalizedSource, normalizedTarget)
                    return (normalizedSource, translated)
                } catch let translationError as TranslationError {
                    if case .notInstalled = translationError, !isKnownInstalledPair(sourceLanguage, targetLanguage) {
                        throw TranslationServiceError.languageModelsMissing(
                            source: localizedLanguageName(for: sourceLanguage),
                            target: localizedLanguageName(for: targetLanguage),
                            sourceLanguage: sourceLanguage,
                            targetLanguage: targetLanguage
                        )
                    }
                    throw translationError
                }
            }

            if !isKnownInstalledPair(sourceLanguage, targetLanguage) {
                throw TranslationServiceError.languageModelsMissing(
                    source: localizedLanguageName(for: sourceLanguage),
                    target: localizedLanguageName(for: targetLanguage),
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage
                )
            }
            throw TranslationError.notInstalled
        @unknown default:
            break
        }

        throw TranslationError.notInstalled
    }

    @available(macOS 26.0, *)
    private func describe(_ status: LanguageAvailability.Status) -> String {
        switch status {
        case .installed:
            return "installed"
        case .supported:
            return "supported"
        case .unsupported:
            return "unsupported"
        @unknown default:
            return "unknown"
        }
    }

    private func normalize(_ language: Locale.Language) -> Locale.Language {
        Locale.Language(identifier: language.minimalIdentifier)
    }

    @available(macOS 26.0, *)
    private func findInstalledVariantPair(
        sourceLanguage: Locale.Language,
        targetLanguage: Locale.Language
    ) async -> (Locale.Language, Locale.Language)? {
        let availability = LanguageAvailability()
        let supportedLanguages = await availability.supportedLanguages
        let sourceCandidates = candidateLanguages(for: sourceLanguage, supportedLanguages: supportedLanguages)
        let targetCandidates = candidateLanguages(for: targetLanguage, supportedLanguages: supportedLanguages)

        for sourceCandidate in sourceCandidates {
            for targetCandidate in targetCandidates {
                let status = await availability.status(from: sourceCandidate, to: targetCandidate)
                if status == .installed {
                    return (sourceCandidate, targetCandidate)
                }
            }
        }

        return nil
    }

    private func candidateLanguages(
        for language: Locale.Language,
        supportedLanguages: [Locale.Language]
    ) -> [Locale.Language] {
        let normalized = normalize(language)
        let base = baseIdentifier(for: normalized)
        var seen = Set<String>()
        var candidates: [Locale.Language] = []

        func appendIfNeeded(_ candidate: Locale.Language) {
            let key = candidate.minimalIdentifier
            if seen.insert(key).inserted {
                candidates.append(candidate)
            }
        }

        appendIfNeeded(normalized)
        appendIfNeeded(language)

        for supported in supportedLanguages where baseIdentifier(for: supported) == base {
            appendIfNeeded(supported)
        }

        return candidates
    }

    private func baseIdentifier(for language: Locale.Language) -> String {
        language.minimalIdentifier.split(separator: "-").first.map(String.init) ?? language.minimalIdentifier
    }

    private func rememberInstalledPair(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) {
        let directKey = pairKey(sourceLanguage, targetLanguage)
        let normalizedKey = pairKey(normalize(sourceLanguage), normalize(targetLanguage))
        let insertedDirect = confirmedInstalledPairs.insert(directKey).inserted
        let insertedNormalized = confirmedInstalledPairs.insert(normalizedKey).inserted
        if insertedDirect || insertedNormalized {
            defaults.set(Array(confirmedInstalledPairs).sorted(), forKey: Keys.confirmedInstalledPairs)
        }
    }

    private func isKnownInstalledPair(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) -> Bool {
        let directKey = pairKey(sourceLanguage, targetLanguage)
        let normalizedKey = pairKey(normalize(sourceLanguage), normalize(targetLanguage))
        return confirmedInstalledPairs.contains(directKey) || confirmedInstalledPairs.contains(normalizedKey)
    }

    private func pairKey(_ sourceLanguage: Locale.Language, _ targetLanguage: Locale.Language) -> String {
        "\(sourceLanguage.minimalIdentifier)->\(targetLanguage.minimalIdentifier)"
    }

    private func detectSourceLanguage(in text: String) throws -> Locale.Language {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else {
            throw TranslationServiceError.unableToIdentifyLanguage
        }
        return Locale.Language(identifier: language.rawValue)
    }

    private func localizedLanguageName(for language: Locale.Language) -> String {
        TranslationLanguage.localizedName(for: language.minimalIdentifier)
    }
}
