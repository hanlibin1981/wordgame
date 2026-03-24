import SwiftUI

/// Navigation destination types for LearningTabView
enum LearningNavDestination: Hashable {
    case levelSelection(WordBook)
    case game(book: WordBook, level: GameLevel)
}

/// Main tab view for the app navigation
struct MainView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Learning Tab
            LearningTabView()
                .tabItem {
                    Label("学习", systemImage: "house.fill")
                }
                .tag(0)

            // Word Books Tab
            WordBookListView()
                .tabItem {
                    Label("词库", systemImage: "books.vertical")
                }
                .tag(1)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
                .tag(2)
        }
        .frame(minWidth: 960, minHeight: 680)
    }
}

/// Learning tab with quick access to continue learning
struct LearningTabView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome Header
                    welcomeHeader

                    // Continue Learning Card
                    if let lastBook = wordBookVM.wordBooks.first {
                        continueLearningCard(book: lastBook)
                    }

                    // All Word Books Grid
                    wordBooksGrid

                    Spacer()
                }
                .padding()
            }
            .background(Color.backgroundMain)
            .navigationTitle("背单词")
            .navigationDestination(for: LearningNavDestination.self) { destination in
                switch destination {
                case .levelSelection(let book):
                    LevelSelectionView(book: book, navigationPath: $navigationPath)
                case .game(let book, let level):
                    GameView(book: book, level: level)
                }
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("欢迎回来!")
                .font(DesignFont.largeTitle)

            Text("今天也要坚持学习哦")
                .font(DesignFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func continueLearningCard(book: WordBook) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("继续学习")
                    .font(DesignFont.headline)
                Spacer()
                Text(book.name)
                    .font(DesignFont.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                navigationPath.append(LearningNavDestination.levelSelection(book))
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(DesignFont.title2)
                    Text("开始闯关")
                        .font(DesignFont.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color.primaryBlue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private var wordBooksGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("选择词库")
                .font(DesignFont.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(wordBookVM.wordBooks) { book in
                    WordBookCard(book: book)
                        .onTapGesture {
                            navigationPath.append(LearningNavDestination.levelSelection(book))
                        }
                }
            }
        }
    }
}

/// Card view for a word book
struct WordBookCard: View {
    let book: WordBook

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: book.isPreset ? "star.fill" : "folder")
                    .font(.system(size: 13))
                    .foregroundColor(book.isPreset ? .warningOrange : .primaryBlue)

                Text(book.typeLabel)
                    .font(DesignFont.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(book.isPreset ? Color.warningOrange.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(4)
                Spacer()
            }

            Text(book.name)
                .font(DesignFont.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let description = book.description {
                Text(description)
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            HStack {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 12))
                Text("\(book.wordCount) 词")
            }
            .font(DesignFont.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(Color.cardBackground)
        .cornerRadius(12)
        .shadow(
            color: isHovered ? Color.primaryBlue.opacity(0.15) : .black.opacity(0.05),
            radius: isHovered ? 12 : 4,
            x: 0,
            y: isHovered ? 6 : 2
        )
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    MainView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(WordBookViewModel())
}
