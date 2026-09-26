import SwiftUI

// MARK: - Games Page

struct GamesPageView: View {
    @ObservedObject var model: AppModel
    @Binding var page: Page
    @Binding var pending: InstallAction?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            searchBar
            if !model.ready { notReadyBanner }
            if model.games.isEmpty {
                emptyState
            } else {
                resultsHeader
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.games) { game in
                            GameRowView(game: game, model: model, pending: $pending)
                        }
                    }
                }
            }
            luaPathFooter
        }
        .padding(.horizontal, 28).padding(.bottom, 20)
    }

    // MARK: Sub-views

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(L(.searchPlaceholder), text: $model.query)
                .textFieldStyle(.plain)
                .onSubmit { model.search() }
                .disabled(model.searching)
            if model.searching { ProgressView().controlSize(.small) }
            Button(L(.searchButton)) { model.search() }
                .buttonStyle(.borderedProminent)
                .disabled(model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.searching)
        }
        .padding(12)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 11))
    }

    private var notReadyBanner: some View {
        HStack {
            Label(L(.chooseBottleInfo), systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(L(.openSettings)) { page = .settings }.controlSize(.small)
        }
    }

    private var resultsHeader: some View {
        HStack {
            Text(L(.searchResultsLabel))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2).foregroundStyle(.secondary)
            Spacer()
            Text("\(model.games.count) \(L(.gamesCount))")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: model.searching ? "magnifyingglass" : "gamecontroller")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(AppTheme.accent)
            Text(model.searching
                 ? L(.searchingLabel)
                 : model.searched
                   ? (model.failed ? "Pencarian belum berhasil" : L(.emptySubtitleSearched))
                   : L(.emptySubtitleNotSearched))
                .font(.system(size: 19, weight: .semibold))
            Text(model.searched ? L(.emptyBodySearched) : L(.emptyBodyNotSearched))
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !model.searched && !model.searching {
                HStack {
                    ForEach(["Portal", "Stardew Valley", "Elden Ring"], id: \.self) { term in
                        Button(term) { model.query = term; model.search() }.controlSize(.small)
                    }
                }.padding(.top, 4)
            }
            Spacer()
        }.frame(maxWidth: .infinity)
    }

    private var luaPathFooter: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.doc")
            Text(L(.luaPathHint))
            Spacer()
            Link("ManifestHub \u{2197}", destination: Catalog.manifestPage)
        }
        .font(.system(size: 11)).foregroundStyle(.secondary)
    }
}

// MARK: - Game Row

struct GameRowView: View {
    let game: Game
    @ObservedObject var model: AppModel
    @Binding var pending: InstallAction?

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: game.image) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    AppTheme.surface
                    Image(systemName: "gamecontroller").foregroundStyle(.secondary)
                }
            }
            .frame(width: 122, height: 55).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                Text(game.name)
                    .font(.system(size: 14, weight: .semibold)).lineLimit(2)
                HStack(spacing: 9) {
                    Text("App ID \(game.id)").foregroundStyle(.secondary)
                    if model.installedLua.contains(game.id) {
                        Label(L(.luaInstalled), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }.font(.system(size: 10))
            }

            Spacer(minLength: 10)

            Button(model.installedLua.contains(game.id) ? L(.updateLua) : L(.downloadLua)) {
                pending = .lua(game)
            }
            .controlSize(.small)
            .disabled(!model.ready || model.busy)
        }
        .padding(13)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 11))
    }
}
