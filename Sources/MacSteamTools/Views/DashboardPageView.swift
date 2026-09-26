import SwiftUI
import AppKit

// MARK: - Dashboard Page

struct DashboardPageView: View {
    @ObservedObject var model: AppModel
    @Binding var pendingUninstall: UninstallAction?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 260), spacing: 16)
    ]

    var body: some View {
        if model.installedLua.isEmpty {
            emptyState
        } else {
            gameGrid
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(L(.dashboardEmpty))
                .font(.system(size: 19, weight: .semibold))
            Text(L(.dashboardEmptyBody))
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28).padding(.bottom, 20)
    }

    // MARK: Game Grid

    private var gameGrid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Section header
                HStack {
                    Text(L(.installedLuaSection))
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(model.installedLua.count) \(L(.installedLuaCount))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(model.installedLua.sorted(), id: \.self) { appID in
                        GameCardView(
                            appID: appID,
                            gameName: model.luaNames[appID],
                            model: model,
                            pendingUninstall: $pendingUninstall
                        )
                    }
                }
            }
            .padding(.horizontal, 28).padding(.bottom, 20)
        }
        .focusable(false)
    }
}

// MARK: - Game Card

struct GameCardView: View {
    let appID: String
    let gameName: String?
    @ObservedObject var model: AppModel
    @Binding var pendingUninstall: UninstallAction?

    @State private var hovered = false

    private var steamImageURL: URL? {
        URL(string: "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover image
            AsyncImage(url: steamImageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    ZStack {
                        AppTheme.accent.opacity(0.10)
                        Image(systemName: "gamecontroller")
                            .foregroundStyle(AppTheme.accent)
                            .font(.system(size: 32))
                    }
                case .empty:
                    ZStack {
                        AppTheme.surface
                        ProgressView().controlSize(.small)
                    }
                @unknown default:
                    AppTheme.surface
                }
            }
            .frame(height: 110)
            .clipped()
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: 11, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 11
            ))

            // Info footer
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(gameName ?? "App \(appID)")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text("App ID \(appID)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    pendingUninstall = .lua(appID)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(L(.uninstallLuaButton))
                .disabled(model.busy)
                .focusable(false)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(hovered ? AppTheme.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .scaleEffect(hovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: hovered)
        .onHover { hovered = $0 }
    }
}

// MARK: - Uninstall Confirmation Sheet

struct UninstallConfirmView: View {
    let action: UninstallAction
    @ObservedObject var model: AppModel
    @Binding var pendingUninstall: UninstallAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(confirmTitle, systemImage: "trash.circle")
                .font(.title3.bold())
                .foregroundStyle(.red)

            Text(confirmBodyText)

            Text(L(.confirmFooter))
                .font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L(.cancelButton)) { pendingUninstall = nil }
                    .keyboardShortcut(.cancelAction)
                Button(confirmLabel, role: .destructive) {
                    pendingUninstall = nil
                    switch action {
                    case .lua(let id): model.uninstallLua(appID: id)
                    case .all:         model.uninstallAll()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26).frame(width: 470)
        .interactiveDismissDisabled()
    }

    private var confirmTitle: String {
        switch action {
        case .lua:  return L(.confirmUninstallLuaTitle)
        case .all:  return L(.confirmUninstallAllTitle)
        }
    }
    private var confirmBodyText: String {
        switch action {
        case .lua(let id): return "\(L(.confirmUninstallLuaBody))\n\nApp ID: \(id)"
        case .all:         return L(.confirmUninstallAllBody)
        }
    }
    private var confirmLabel: String {
        switch action {
        case .lua:  return L(.uninstallLuaButton)
        case .all:  return L(.uninstallAllButton)
        }
    }
}
