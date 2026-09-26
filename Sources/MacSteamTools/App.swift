import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let image = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) {
            image.isTemplate = false
            if let tinted = image.withSymbolConfiguration(.init(paletteColors: [NSColor(AppTheme.accent)])) {
                NSApplication.shared.applicationIconImage = tinted
            } else {
                NSApplication.shared.applicationIconImage = image
            }
        }
    }
}

@main
struct MacSteamToolsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("MacSteamTools") { ContentView() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1020, height: 740)
    }
}

// MARK: - Root Content View

struct ContentView: View {
    @StateObject private var model = AppModel()
    @ObservedObject  private var loc   = Localization.shared

    @State private var page: Page = .dashboard
    @State private var pending: InstallAction?
    @State private var pendingUninstall: UninstallAction?
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(model: model, page: $page)
            Divider().overlay(Color.white.opacity(0.04))
            mainContent
        }
        .frame(minWidth: 900, minHeight: 680)
        .preferredColorScheme(.dark)
        .tint(AppTheme.accent)
        // Install confirmation sheet
        .sheet(item: $pending) { action in
            InstallConfirmView(action: action, model: model, pending: $pending)
        }
        // Uninstall confirmation sheet
        .sheet(item: $pendingUninstall) { action in
            UninstallConfirmView(action: action, model: model, pendingUninstall: $pendingUninstall)
        }
        // Log / detail sheet
        .sheet(isPresented: $showDetails) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Detail aktivitas").font(.title2.bold())
                ScrollView {
                    Text(model.status)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("Tutup") { showDetails = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 560, height: 300)
        }
    }

    // MARK: Main content area

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            pageHeader
            pageBody
            FooterView(model: model, showDetails: $showDetails)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.bg)
    }

    private var pageHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 7) {
                Text(headerTitle).font(.system(size: 29, weight: .bold))
                Text(headerSubtitle).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Label("CrossOver", systemImage: "desktopcomputer")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(AppTheme.surface, in: Capsule())
        }.padding(28)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch page {
        case .games:
            GamesPageView(model: model, page: $page, pending: $pending)
        case .dashboard:
            DashboardPageView(model: model, pendingUninstall: $pendingUninstall)
        case .settings:
            SettingsPageView(model: model, pending: $pending, pendingUninstall: $pendingUninstall)
        }
    }

    private var headerTitle: String {
        switch page {
        case .games:     return L(.headerGames)
        case .dashboard: return L(.headerDashboard)
        case .settings:  return L(.headerSettings)
        }
    }
    private var headerSubtitle: String {
        switch page {
        case .games:     return L(.subGames)
        case .dashboard: return L(.subDashboard)
        case .settings:  return L(.subSettings)
        }
    }
}

// MARK: - Footer View

struct FooterView: View {
    @ObservedObject var model: AppModel
    @Binding var showDetails: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if model.busy {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: model.failed ? "exclamationmark.circle" : "info.circle")
                    .foregroundStyle(model.failed ? Color.orange : .secondary)
            }
            Text(model.status)
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .lineLimit(2).help(model.status)
            Spacer(minLength: 4)
            if model.failed {
                Button(L(.detailButton)) { showDetails = true }.controlSize(.small)
            }
        }
        .padding(.horizontal, 28).padding(.vertical, 15)
        .frame(minHeight: 58)
        .background(Color.white.opacity(0.025))
    }
}

// MARK: - Install Confirmation Sheet

struct InstallConfirmView: View {
    let action: InstallAction
    @ObservedObject var model: AppModel
    @Binding var pending: InstallAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L(.confirmTitle), systemImage: "pause.circle").font(.title3.bold())
            Text("\(L(.confirmBottle)) \(model.prefix?.lastPathComponent ?? "—")")
                .foregroundStyle(.secondary)

            switch action {
            case .modules:
                Text(L(.confirmModulesBody))
            case .lua(let game):
                Text(LF(.confirmLuaBody, game.name, game.id))
            }

            Text(L(.confirmFooter)).font(.caption).foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L(.cancelButton)) { pending = nil }
                    .keyboardShortcut(.cancelAction)
                Button(L(.proceedButton)) {
                    pending = nil
                    switch action {
                    case .modules:       model.installModules()
                    case .lua(let game): model.installLua(game)
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26).frame(width: 470)
        .interactiveDismissDisabled()
    }
}
