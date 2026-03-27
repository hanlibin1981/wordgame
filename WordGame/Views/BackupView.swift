import SwiftUI

/// 备份与恢复视图
struct BackupView: View {
    @State private var backups: [BackupFile] = []
    @State private var isCreating = false
    @State private var isRestoring = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var selectedRestore: BackupFile?
    @State private var showRestoreConfirm = false
    @State private var isDeleting = false

    var body: some View {
        List {
            // 创建备份
            Section {
                Button(action: createBackup) {
                    HStack {
                        Image(systemName: "arrow.up.doc")
                            .foregroundColor(.primaryBlue)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("立即备份")
                                .font(.headline)
                            Text("保存当前所有词书及学习进度")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if isCreating {
                            ProgressView()
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCreating)
            } header: {
                Text("新建备份")
            } footer: {
                Text("备份文件保存在本地，包含词书、学习进度数据。")
            }

            // 备份列表
            if backups.isEmpty {
                Section("已备份文件") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("暂无备份")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                }
            } else {
                Section("已备份文件（\(backups.count) 个）") {
                    ForEach(backups) { backup in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundColor(.primaryBlue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(backup.shortDate)
                                    .font(.subheadline)
                                Text("\(backup.formattedSize)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // 恢复按钮
                            Button {
                                selectedRestore = backup
                                showRestoreConfirm = true
                            } label: {
                                Text("恢复")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.primaryBlue.opacity(0.12))
                                    .foregroundColor(.primaryBlue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isRestoring)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteBackups)
                }
            }
        }
        .navigationTitle("备份与恢复")
        .modifier(NavigationBarTitleInlineModifier())
        .onAppear(perform: loadBackups)
        .alert("恢复备份", isPresented: $showRestoreConfirm) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                if let b = selectedRestore {
                    restoreBackup(b)
                }
            }
        } message: {
            if let b = selectedRestore {
                Text("将用「\(b.shortDate)」的备份覆盖当前数据，此操作不可撤销。")
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("成功", isPresented: $showSuccess) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(successMessage)
        }
        .overlay {
            if isRestoring {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在恢复...")
                            .font(.headline)
                    }
                    .padding(32)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private func loadBackups() {
        backups = BackupService.shared.listBackups()
    }

    private func createBackup() {
        isCreating = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try BackupService.shared.createBackup()
                DispatchQueue.main.async {
                    isCreating = false
                    loadBackups()
                    successMessage = "备份已保存"
                    showSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isCreating = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func restoreBackup(_ backup: BackupFile) {
        isRestoring = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try BackupService.shared.restoreBackup(backup)
                DispatchQueue.main.async {
                    isRestoring = false
                    successMessage = "已从备份恢复"
                    showSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isRestoring = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    private func deleteBackups(at offsets: IndexSet) {
        isDeleting = true
        for i in offsets {
            let backup = backups[i]
            try? BackupService.shared.deleteBackup(backup)
        }
        DispatchQueue.main.async {
            isDeleting = false
            loadBackups()
        }
    }
}

#Preview {
    NavigationStack {
        BackupView()
    }
}
