import Foundation

enum DraftRestoreTimeout: Int, CaseIterable, Identifiable {
    case seconds10 = 10
    case seconds15 = 15
    case seconds30 = 30
    case seconds45 = 45
    case seconds60 = 60

    var id: Int { rawValue }

    var displayName: String {
        "\(rawValue) seconds"
    }
}

final class TranslationLanguageStore {
    private enum Keys {
        static let sourceLanguageID = "default_source_language_id"
        static let targetLanguageID = "default_target_language_id"
        static let draftRestoreTimeout = "draft_restore_timeout"
    }

    let availableLanguages: [TranslationLanguage]
    private let defaults: UserDefaults

    init(
        availableLanguages: [TranslationLanguage] = TranslationLanguage.all,
        defaults: UserDefaults = .standard
    ) {
        self.availableLanguages = availableLanguages
        self.defaults = defaults
    }

    var defaultSourceLanguageID: String {
        get {
            let storedID = defaults.string(forKey: Keys.sourceLanguageID) ?? TranslationLanguage.autoDetectID
            if storedID == TranslationLanguage.autoDetectID {
                return storedID
            }
            return availableLanguages.contains(where: { $0.id == storedID }) ? storedID : TranslationLanguage.autoDetectID
        }
        set {
            defaults.set(newValue, forKey: Keys.sourceLanguageID)
        }
    }

    var defaultSourceLanguage: TranslationLanguage? {
        get {
            language(for: defaultSourceLanguageID)
        }
        set {
            defaultSourceLanguageID = newValue?.id ?? TranslationLanguage.autoDetectID
        }
    }

    var defaultTargetLanguageID: String {
        get {
            guard
                let storedID = defaults.string(forKey: Keys.targetLanguageID),
                availableLanguages.contains(where: { $0.id == storedID })
            else {
                return TranslationLanguage.fallbackTarget.id
            }
            return storedID
        }
        set {
            defaults.set(newValue, forKey: Keys.targetLanguageID)
        }
    }

    var defaultTargetLanguage: TranslationLanguage {
        get {
            language(for: defaultTargetLanguageID) ?? .fallbackTarget
        }
        set {
            defaultTargetLanguageID = newValue.id
        }
    }

    var draftRestoreTimeout: DraftRestoreTimeout {
        get {
            DraftRestoreTimeout(rawValue: defaults.integer(forKey: Keys.draftRestoreTimeout)) ?? .seconds30
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.draftRestoreTimeout)
        }
    }

    func language(for id: String) -> TranslationLanguage? {
        availableLanguages.first(where: { $0.id == id })
    }
}
