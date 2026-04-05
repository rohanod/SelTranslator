import SwiftUI

enum AppUI {
    enum Spacing {
        static let xSmall: CGFloat = 6
        static let small: CGFloat = 10
        static let medium: CGFloat = 14
        static let large: CGFloat = 18
        static let xLarge: CGFloat = 24
    }

    enum Radius {
        static let panel: CGFloat = 30
        static let editor: CGFloat = 18
        static let control: CGFloat = 12
        static let pill: CGFloat = 999
    }

    enum FontSize {
        static let caption: CGFloat = 11
        static let body: CGFloat = 14
        static let emphasis: CGFloat = 15
        static let title: CGFloat = 18
        static let headline: CGFloat = 22
    }

    static let separator = Color.primary.opacity(0.08)
    static let quietSecondary = Color.primary.opacity(0.55)
}

struct AppPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: AppUI.Radius.panel, style: .continuous)
            .fill(.regularMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: AppUI.Radius.panel, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.1), radius: 24, y: 12)
    }
}

struct AppSurface<Content: View>: View {
    let title: String?
    let detail: String?
    let showDivider: Bool
    @ViewBuilder let content: Content

    init(
        title: String? = nil,
        detail: String? = nil,
        showDivider: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.showDivider = showDivider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.small) {
            if let title {
                Text(title)
                    .font(.system(size: AppUI.FontSize.caption, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content

            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(AppUI.quietSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            if showDivider {
                Divider()
                    .overlay(AppUI.separator)
                    .padding(.top, AppUI.Spacing.medium)
                    .offset(y: AppUI.Spacing.large)
            }
        }
    }
}

struct AppSectionCard<Content: View>: View {
    let title: String
    let description: String?
    @ViewBuilder let content: Content

    init(
        title: String,
        description: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppUI.Spacing.medium) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: AppUI.FontSize.emphasis, weight: .semibold, design: .rounded))

                if let description {
                    Text(description)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(AppUI.quietSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(.vertical, AppUI.Spacing.small)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppUI.FontSize.body, weight: .medium, design: .rounded))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.13))
            )
            .foregroundStyle(.primary)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: AppUI.FontSize.body, weight: .medium, design: .rounded))
            .padding(.horizontal, 10)
            .frame(height: 28)
            .foregroundStyle(.secondary)
            .opacity(configuration.isPressed ? 0.72 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .foregroundStyle(.secondary)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.05))
            )
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct AppStatusBadge: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AppUI.quietSecondary)
    }
}

struct AppHintText: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(AppUI.quietSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
