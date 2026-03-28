import SwiftUI
import UniformTypeIdentifiers

/// List view for managing word books
struct WordBookListView: View {
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var showAddBook = false
    @State private var showImportCSV = false
    @State private var showDeleteAlert = false
    @State private var bookToDelete: WordBook?
    @State private var selectedBook: WordBook?

    /// Cached preset books — avoids repeated filter calls on the same data
    private var presetBooks: [WordBook] {
        wordBookVM.wordBooks.filter { $0.isPreset }
    }

    /// Cached custom (non-preset) books
    private var customBooks: [WordBook] {
        wordBookVM.wordBooks.filter { !$0.isPreset }
    }

    var body: some View {
        NavigationStack {
            List {
                // Preset Vocabularies Section
                Section("预置词库") {
                    ForEach(presetBooks) { book in
                        WordBookRow(book: book)
                            .onTapGesture {
                                selectedBook = book
                            }
                    }
                }

                // Custom Vocabularies Section
                Section("自定义词库") {
                    if customBooks.isEmpty {
                        Text("暂无自定义词库")
                            .font(DesignFont.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(customBooks) { book in
                            WordBookRow(book: book)
                                .onTapGesture {
                                    selectedBook = book
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        bookToDelete = book
                                        showDeleteAlert = true
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .navigationTitle("词库管理")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button(action: { showAddBook = true }) {
                            Label("手动添加", systemImage: "plus")
                        }

                        Button(action: { showImportCSV = true }) {
                            Label("导入CSV", systemImage: "doc.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .refreshable {
                await wordBookVM.refreshWordBooks()
            }
            .sheet(isPresented: $showAddBook) {
                AddWordBookView()
            }
            .sheet(isPresented: $showImportCSV) {
                ImportCSVView()
            }
            .sheet(item: $selectedBook) { book in
                WordBookDetailView(book: book)
            }
            .alert("删除词库", isPresented: $showDeleteAlert, presenting: bookToDelete) { book in
                Button("取消", role: .cancel) { }
                Button("删除", role: .destructive) {
                    Task {
                        try? await wordBookVM.deleteWordBook(book)
                    }
                }
            } message: { book in
                Text("确定要删除「\(book.name)」吗？此操作不可撤销。")
            }
        }
    }
}

/// Row view for a single word book
struct WordBookRow: View {
    let book: WordBook

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(book.isPreset ? Color.warningOrange.opacity(0.15) : Color.primaryBlue.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: book.isPreset ? "star.fill" : "folder")
                    .foregroundColor(book.isPreset ? .warningOrange : .primaryBlue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.name)
                    .font(DesignFont.headline)

                HStack(spacing: 8) {
                    Text(book.typeLabel)
                        .font(DesignFont.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)

                    Text("\(book.wordCount) 词")
                        .font(DesignFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DesignFont.caption)
                .foregroundStyle(.tertiary)
                .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isHovered ? Color.gray.opacity(0.08) : Color.clear)
        .cornerRadius(8)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// View for adding a new word book
struct AddWordBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var name = ""
    @State private var description = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("创建新词库")
                    .font(DesignFont.title2)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("词库名称")
                        .font(DesignFont.subheadline)
                    TextField("例如：我的考研词汇", text: $name)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("描述（可选）")
                        .font(DesignFont.subheadline)
                    TextField("简要描述这个词库的内容", text: $description)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.errorRed)
                    .font(DesignFont.caption)
            }

            Spacer()

            // Create Button
            Button(action: createBook) {
                if isCreating {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("创建词库")
                        .font(DesignFont.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(name.isEmpty ? Color.gray : Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(name.isEmpty || isCreating)
        }
        .padding()
        .frame(width: 400, height: 320)
    }

    private func createBook() {
        isCreating = true
        errorMessage = nil

        Task {
            do {
                try await wordBookVM.createWordBook(
                    name: name,
                    description: description.isEmpty ? nil : description
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isCreating = false
            }
        }
    }
}

/// View for importing CSV files
struct ImportCSVView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var wordBookVM: WordBookViewModel
    @State private var bookName = ""
    @State private var bookDescription = ""
    @State private var selectedFile: URL?
    @State private var showFilePicker = false
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("导入CSV词库")
                    .font(DesignFont.title2)
                Spacer()
                Button("关闭") {
                    dismiss()
                }
            }

            // Form
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("词库名称")
                        .font(DesignFont.subheadline)
                    TextField("为这个词库起个名字", text: $bookName)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("描述（可选）")
                        .font(DesignFont.subheadline)
                    TextField("简要描述", text: $bookDescription)
                        .font(DesignFont.subheadline)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("CSV文件")
                        .font(DesignFont.subheadline)

                    Button(action: { showFilePicker = true }) {
                        HStack {
                            Image(systemName: selectedFile != nil ? "checkmark.circle.fill" : "doc.badge.plus")
                            Text(selectedFile?.lastPathComponent ?? "选择CSV文件...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }

                Text("CSV格式：word,phonetic,meaning,sentence（第一行可省略标题）")
                    .font(DesignFont.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.errorRed)
                    .font(DesignFont.caption)
            }

            Spacer()

            // Import Button
            Button(action: importCSV) {
                if isImporting {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Text("导入词库")
                        .font(DesignFont.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(bookName.isEmpty || selectedFile == nil ? Color.gray : Color.primaryBlue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(bookName.isEmpty || selectedFile == nil || isImporting)
        }
        .padding()
        .frame(width: 400, height: 420)
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedFile = urls.first
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importCSV() {
        guard let url = selectedFile else { return }

        isImporting = true
        errorMessage = nil

        Task {
            do {
                // VocabImportService.importCSV(from:) handles security-scoped resource
                // access internally. Do NOT pre-access here — that would cause double-access
                // and potential resource leaks if the inner call throws.
                try await wordBookVM.importCSV(
                    from: url,
                    bookName: bookName,
                    description: bookDescription.isEmpty ? nil : bookDescription
                )

                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}

#Preview {
    WordBookListView()
        .environmentObject(WordBookViewModel())
}
