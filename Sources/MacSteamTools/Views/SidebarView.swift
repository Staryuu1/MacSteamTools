import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @ObservedObject var model: AppModel
    @Binding var page: Page

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L(.appName)).font(.system(size: 17, weight: .bold))
                    Text("TOOLS")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(3).foregroundStyle(.secondary)
                }
            }.padding(.bottom, 34)

            // Nav
            Text(L(.workspaceSection))
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.7).foregroundStyle(.secondary).padding(.bottom, 12)

            ForEach(Page.allCases, id: \.self) { item in
                navButton(item)
            }

            Spacer()

            // Bottle status card
            VStack(alignment: .leading, spacing: 10) {
                Label(
                    model.ready ? L(.bottleActive) : L(.setupRequired),
                    systemImage: model.ready ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.caption)
                .foregroundStyle(model.ready ? Color.green : .secondary)

                Text(model.prefix?.lastPathComponent ?? L(.noBottleSelected))
                    .font(.system(size: 13, weight: .semibold)).lineLimit(2)

                Button { page = .settings } label: {
                    Text(L(.openInSettings)).font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.accent)
                .focusable(false)

                Divider().padding(.vertical, 2)

                Button { model.launch() } label: {
                    Label(L(.openSteam), systemImage: "play.fill")
                        .frame(maxWidth: .infinity).padding(.vertical, 5)
                }
                .buttonStyle(.bordered)
                .disabled(!model.ready || model.busy)
                .focusable(false)
            }
            .padding(14)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))

            Text(L(.appVersion))
                .font(.system(size: 10)).foregroundStyle(.tertiary).padding(.top, 17)
        }
        .padding(.horizontal, 18).padding(.top, 38).padding(.bottom, 20)
        .frame(width: 204)
        .background(AppTheme.sidebar)
    }

    private func navButton(_ item: Page) -> some View {
        Button { page = item } label: {
            HStack(spacing: 11) {
                Image(systemName: item.icon).frame(width: 20)
                Text(item.localizedName).fontWeight(.medium)
                Spacer()
                if page == item {
                    Circle().fill(AppTheme.accent).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)
            .foregroundStyle(page == item ? Color.white : Color.secondary)
            .background(
                page == item ? AppTheme.accent.opacity(0.16) : .clear,
                in: RoundedRectangle(cornerRadius: 9)
            )
            .contentShape(Rectangle())
        }.buttonStyle(.plain).focusable(false).padding(.bottom, 5)
    }
}
