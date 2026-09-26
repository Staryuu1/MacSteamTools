import SwiftUI

// MARK: - Settings Page

struct SettingsPageView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var loc = Localization.shared
    @Binding var pending: InstallAction?
    @Binding var pendingUninstall: UninstallAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Spacer()
                    Picker("", selection: $loc.language) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                .padding(.bottom, -8)

                crossOverCard
                modulesCard
                librariesCard
                quickLinks
                dangerCard
            }
            .padding(.horizontal, 28).padding(.bottom, 22)
        }
    }

    // MARK: CrossOver Card

    private var crossOverCard: some View {
        CardView(title: L(.crossOverCardTitle), subtitle: L(.crossOverCardSubtitle), icon: "desktopcomputer") {
            HStack {
                Picker(L(.pickBottle), selection: Binding(
                    get: { model.prefix?.path ?? "" },
                    set: { if !$0.isEmpty { model.selectBottle(URL(fileURLWithPath: $0)) } }
                )) {
                    Text(L(.chooseFolder)).tag("")
                    ForEach(model.bottles, id: \.path) {
                        Text($0.lastPathComponent).tag($0.path)
                    }
                }.disabled(model.busy)
                Button { model.scan() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help(L(.rescanBottle))
                .disabled(model.busy)
                Button(L(.chooseFolder)) { model.chooseBottle() }.disabled(model.busy)
            }

            PathRowView(
                label: L(.steamLabel),
                path: model.steam?.path ?? L(.steamNotFound),
                button: L(.changeButton)
            ) { model.chooseSteam() }
            .disabled(model.prefix == nil || model.busy)

            DisclosureGroup(L(.crossOverLocation)) {
                PathRowView(
                    label: L(.crossOverAppLabel),
                    path: model.crossOverApp.path,
                    button: L(.pickButton)
                ) { model.chooseCrossOver() }
                .padding(.top, 8)
            }
            .font(.caption).foregroundStyle(.secondary)
            .disabled(model.busy)
        }
    }

    // MARK: Modules Card

    private var modulesCard: some View {
        CardView(title: L(.modulesCardTitle), subtitle: L(.modulesCardSubtitle), icon: "shippingbox") {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.release.map { "\(L(.latestRelease)) \($0.tag_name)" } ?? L(.versionCheckedAtInstall))
                        .font(.system(size: 13, weight: .medium))
                    Text(model.installedVersion.map { "\(L(.lastInstalled)) \($0)" } ?? L(.notYetInstalled))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if model.checkingRelease { ProgressView().controlSize(.small) }
                Button(L(.checkVersionButton)) { model.checkRelease() }
                    .disabled(model.checkingRelease || model.busy)
            }
            Divider()
            HStack {
                Label(L(.autoBackupLabel), systemImage: "clock.arrow.circlepath")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(model.installedVersion == nil ? L(.installModulesButton) : L(.updateModulesButton)) {
                    pending = .modules
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.ready || model.busy)
            }
            Link(L(.modulesSource), destination: Catalog.releasePage).font(.caption)
        }
    }

    // MARK: Libraries Card

    private var librariesCard: some View {
        CardView(title: L(.librariesCardTitle), subtitle: L(.librariesCardSubtitle), icon: "slider.horizontal.3") {
            ForEach(Installer.dlls, id: \.self) { name in
                HStack {
                    Image(systemName: "doc").foregroundStyle(.secondary)
                    Text(name).font(.system(size: 12, design: .monospaced))
                    Spacer()
                    Text(model.overrides[name] ?? L(.notChecked))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(model.overrides[name] == "native,builtin" ? Color.green : .secondary)
                }
            }
            HStack {
                Text(L(.librariesTarget)).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(L(.checkLibrariesButton)) { model.checkLibraries() }
                    .disabled(!model.ready || model.busy)
                Button(L(.openWinecfgButton)) { model.launch(winecfg: true) }
                    .disabled(!model.ready || model.busy)
            }.padding(.top, 5)
        }
    }

    // MARK: Quick links

    private var quickLinks: some View {
        HStack {
            if let steam = model.steam {
                Button(L(.openSteamFolder)) { NSWorkspace.shared.open(steam) }
            }
            if let backup = model.backup {
                Button(L(.viewBackup)) { NSWorkspace.shared.open(backup) }
            }
        }.controlSize(.small)
    }

    // MARK: Danger Zone Card

    private var dangerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 17))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L(.dangerZoneTitle)).font(.system(size: 16, weight: .semibold)).foregroundStyle(.red)
                    Text(L(.dangerZoneSubtitle)).font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider().opacity(0.5)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(.uninstallAllButton))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(L(.dangerZoneUninstallDesc))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(role: .destructive) {
                    pendingUninstall = .all
                } label: {
                    Label(L(.uninstallAllButton), systemImage: "trash.fill")
                }
                .tint(.red)
                .disabled(!model.ready || model.busy)
            }
        }
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 13))
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Reusable Card

struct CardView<Content: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.accent)
                    .font(.system(size: 17))
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.system(size: 16, weight: .semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(20)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 13))
    }
}

// MARK: - Reusable Path Row

struct PathRowView: View {
    let label: String
    let path: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(label).font(.caption).fontWeight(.medium)
                Text(path)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle).help(path)
            }
            Spacer()
            Button(button, action: action).controlSize(.small)
        }
    }
}
