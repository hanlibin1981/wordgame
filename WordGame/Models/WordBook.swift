import Foundation

/// Represents a collection of words (a vocabulary book)
struct WordBook: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var description: String?
    var wordCount: Int
    var isPreset: Bool  // true for built-in vocabulary books
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        wordCount: Int = 0,
        isPreset: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.wordCount = wordCount
        self.isPreset = isPreset
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Display text for the book type
    var typeLabel: String {
        isPreset ? "官方词库" : "自定义"
    }
}

/// Preset vocabulary book types
enum PresetVocabulary: String, CaseIterable {
    // Use the full bundled 3500词表 for the default preset.
    case highSchool3500 = "high_school_3500"
    case cet4 = "cet4"
    case primarySchool = "primary_school"
    case juniorHigh = "junior_high"

    var displayName: String {
        switch self {
        case .highSchool3500:
            return "高中英语3500词"
        case .cet4:
            return "大学英语四级词汇"
        case .primarySchool:
            return "小学英语词汇"
        case .juniorHigh:
            return "初中英语词汇"
        }
    }

    var description: String {
        switch self {
        case .highSchool3500:
            return "高中阶段必备词汇，涵盖高考所有考点"
        case .cet4:
            return "大学英语四级考试必备词汇"
        case .primarySchool:
            return "小学阶段必备词汇，适合英语入门学习"
        case .juniorHigh:
            return "初中阶段必备词汇，中考备考核心词汇"
        }
    }

    /// Bundle filename for this preset vocabulary.
    var fileName: String {
        return "\(rawValue).json"
    }
}
