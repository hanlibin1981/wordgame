import Foundation
import SQLite3

/// 备份文件信息
struct BackupFile: Identifiable, Equatable {
    let id: String  // 文件名（不含路径）
    var name: String { id }
    let date: Date
    let size: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }
}

/// 备份与恢复服务
final class BackupService {
    static let shared = BackupService()

    private init() {}

    // MARK: - 路径

    var backupsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WordGame/backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func newBackupFileName() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return "vocab_backup_\(f.string(from: Date())).sql"
    }

    // MARK: - 创建备份

    /// 导出词书数据为 SQL 文件
    @discardableResult
    func createBackup() throws -> URL {
        let fileName = newBackupFileName()
        let fileURL = backupsDirectory.appendingPathComponent(fileName)

        let dbPath = DatabaseService.shared.dbPath
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "BackupService", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法打开数据库"])
        }
        defer { sqlite3_close(db) }

        var sql = ""
        sql += "-- WordGame Vocabulary Backup\n"
        sql += "-- Created: \(ISO8601DateFormatter().string(from: Date()))\n"
        sql += "-- Restore: sqlite3 wordgame.db < filename.sql\n\n"
        sql += "BEGIN TRANSACTION;\n\n"

        // Helper to select rows and append INSERT statements
        func exportTable(_ table: String, _ cols: String, _ orderBy: String = "created_at") throws {
            var stmt: OpaquePointer?
            let query = "SELECT \(cols) FROM \(table) ORDER BY \(orderBy)"
            guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
                throw NSError(domain: "BackupService", code: 3, userInfo: [NSLocalizedDescriptionKey: "查询失败: \(table)"])
            }
            defer { sqlite3_finalize(stmt) }

            sql += "-- TABLE: \(table)\n"
            let colCount = sqlite3_column_count(stmt)
            let columnList = cols

            while sqlite3_step(stmt) == SQLITE_ROW {
                sql += "INSERT INTO \(table) (\(columnList)) VALUES("
                for i in 0..<colCount {
                    if i > 0 { sql += "," }
                    let type = sqlite3_column_type(stmt, i)
                    switch type {
                    case SQLITE_NULL:   sql += "NULL"
                    case SQLITE_INTEGER: sql += "\(sqlite3_column_int64(stmt, i))"
                    case SQLITE_FLOAT:   sql += "\(sqlite3_column_double(stmt, i))"
                    default:
                        if let v = sqlite3_column_text(stmt, i) {
                            sql += "'\(String(cString: v).replacingOccurrences(of: "'", with: "''"))'"
                        } else { sql += "NULL" }
                    }
                }
                sql += ");\n"
            }
            sql += "\n"
        }

        try exportTable("word_books", "id,name,description,word_count,is_preset,created_at,updated_at")
        try exportTable("words", "id,book_id,word,phonetic,meaning,sentence,sentence_translation,audio_url,mastery_level,wrong_count,last_reviewed_at,created_at")
        try exportTable("game_progress", "id,book_id,current_chapter,current_stage,stars_earned,total_correct,total_answered,is_completed,updated_at", "updated_at")
        try exportTable("learning_records", "id,word_id,book_id,result,question_type,answer_time_ms,created_at")
        try exportTable("level_records", "id,book_id,chapter,stage,is_passed,stars_earned,completed_at", "completed_at")

        sql += "COMMIT;\n"

        let tempURL = backupsDirectory.appendingPathComponent("temp_\(fileName)")
        try sql.write(to: tempURL, atomically: true, encoding: .utf8)
        try FileManager.default.moveItem(at: tempURL, to: fileURL)
        return fileURL
    }

    // MARK: - 列出备份

    func listBackups() -> [BackupFile] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey], options: .skipsHiddenFiles) else {
            return []
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"

        return files
            .filter { $0.pathExtension == "sql" }
            .compactMap { url -> BackupFile? in
                let name = url.lastPathComponent
                let dateStr = String(name.dropFirst("vocab_backup_".count).dropLast(".sql".count))
                let date = dateFormatter.date(from: dateStr) ?? Date()
                let size = (try? fm.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                return BackupFile(id: name, date: date, size: size)
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - 删除备份

    func deleteBackup(_ backup: BackupFile) throws {
        let fileURL = backupsDirectory.appendingPathComponent(backup.id)
        try FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - 恢复备份

    func restoreBackup(_ backup: BackupFile) throws {
        let fileURL = backupsDirectory.appendingPathComponent(backup.id)
        let sql = try String(contentsOf: fileURL, encoding: .utf8)

        let dbPath = DatabaseService.shared.dbPath
        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            throw NSError(domain: "BackupService", code: 2, userInfo: [NSLocalizedDescriptionKey: "无法打开数据库"])
        }
        defer { sqlite3_close(db) }

        // Wrap everything in an exclusive transaction so cleanup+restore is atomic.
        // On any failure we roll back, leaving the DB untouched.
        var errMsg: UnsafeMutablePointer<CChar>?

        defer { sqlite3_free(errMsg) }

        let beginCode = sqlite3_exec(db, "BEGIN EXCLUSIVE TRANSACTION;", nil, nil, &errMsg)
        if beginCode != SQLITE_OK {
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            throw NSError(domain: "BackupService", code: Int(beginCode), userInfo: [NSLocalizedDescriptionKey: "BEGIN EXCLUSIVE TRANSACTION failed: \(msg)"])
        }

        let cleanupSQL = """
        PRAGMA foreign_keys = OFF;
        DELETE FROM learning_records;
        DELETE FROM level_records;
        DELETE FROM game_progress;
        DELETE FROM words;
        DELETE FROM word_books;
        PRAGMA foreign_keys = ON;
        """

        let cleanupCode = sqlite3_exec(db, cleanupSQL, nil, nil, &errMsg)
        if cleanupCode != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            throw NSError(domain: "BackupService", code: Int(cleanupCode), userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let code = sqlite3_exec(db, sql, nil, nil, &errMsg)
        if code != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            throw NSError(domain: "BackupService", code: Int(code), userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let commitCode = sqlite3_exec(db, "COMMIT;", nil, nil, &errMsg)
        if commitCode != SQLITE_OK {
            sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            let msg = errMsg != nil ? String(cString: errMsg!) : "Unknown error"
            throw NSError(domain: "BackupService", code: Int(commitCode), userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}
