# WordGame - macOS 背单词游戏 设计规格书

## 1. 项目概述

**项目名称**: WordGame
**项目类型**: macOS 桌面教育游戏应用
**核心功能**: 通过游戏闯关模式学习英语词汇，支持预制词库和自定义词库管理
**目标用户**: 学生、英语学习者

---

## 2. 技术架构

### 2.1 技术选型

| 层次 | 技术 | 说明 |
|------|------|------|
| UI 框架 | SwiftUI | 现代化声明式UI |
| 数据持久化 | SQLite.swift | 稳定轻量的SQLite封装 |
| 数据库 | SQLite | 独立.db文件 |
| 音频 | AVFoundation | 单词发音播放 |
| 架构模式 | MVVM | 分离视图与业务逻辑 |

### 2.2 项目结构

```
WordGame/
├── App/
│   ├── WordGameApp.swift          # 应用入口
│   └── ContentView.swift          # 根视图
├── Models/
│   ├── Word.swift                  # 单词模型
│   ├── WordBook.swift              # 单词书模型
│   ├── GameLevel.swift             # 关卡模型
│   └── GameProgress.swift          # 游戏进度模型
├── ViewModels/
│   ├── WordBookViewModel.swift     # 单词书管理
│   ├── GameViewModel.swift         # 游戏逻辑
│   └── LearningViewModel.swift     # 学习模式
├── Views/
│   ├── MainView.swift              # 主界面
│   ├── WordBookListView.swift      # 单词书列表
│   ├── WordBookDetailView.swift    # 单词书详情
│   ├── GameView.swift              # 游戏闯关界面
│   ├── LearningView.swift          # 学习界面
│   └── SettingsView.swift          # 设置界面
├── Services/
│   ├── DatabaseService.swift       # 数据库服务
│   ├── VocabImportService.swift    # 词库导入服务
│   └── AudioService.swift          # 音频服务
├── Resources/
│   ├── Assets.xcassets             # 资源文件
│   └── Vocabularies/               # 预置词库
│       ├── high_school_3500.json
│       └── cet4.json
└── Supporting/
    └── Info.plist
```

---

## 3. 数据模型

### 3.1 数据库表结构

```sql
-- 单词书表
CREATE TABLE word_books (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    word_count INTEGER DEFAULT 0,
    is_preset INTEGER DEFAULT 0,  -- 0: 用户自定义, 1: 预制词库
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- 单词表
CREATE TABLE words (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    word TEXT NOT NULL,
    phonetic TEXT,                -- 音标
    meaning TEXT NOT NULL,         -- 中文释义
    sentence TEXT,                 -- 例句
    audio_url TEXT,                -- 发音音频路径
    mastery_level INTEGER DEFAULT 0, -- 掌握程度 0-5
    wrong_count INTEGER DEFAULT 0,  -- 错误次数
    last_reviewed_at REAL,         -- 上次复习时间
    created_at REAL NOT NULL,
    FOREIGN KEY (book_id) REFERENCES word_books(id)
);

-- 游戏进度表
CREATE TABLE game_progress (
    id TEXT PRIMARY KEY,
    book_id TEXT NOT NULL,
    current_level INTEGER DEFAULT 1,
    total_levels INTEGER NOT NULL,
    stars_earned INTEGER DEFAULT 0,  -- 累计星星数
    is_completed INTEGER DEFAULT 0,
    updated_at REAL NOT NULL,
    FOREIGN KEY (book_id) REFERENCES word_books(id)
);

-- 学习记录表
CREATE TABLE learning_records (
    id TEXT PRIMARY KEY,
    word_id TEXT NOT NULL,
    result INTEGER NOT NULL,       -- 0: 错误, 1: 正确
    answer_time_ms INTEGER,        -- 答题耗时
    question_type TEXT NOT NULL,   -- choice/spelling/listening
    created_at REAL NOT NULL,
    FOREIGN KEY (word_id) REFERENCES words(id)
);
```

### 3.2 模型定义

```swift
// Word.swift
struct Word: Identifiable, Codable {
    let id: String
    var bookId: String
    var word: String
    var phonetic: String?
    var meaning: String
    var sentence: String?
    var audioUrl: String?
    var masteryLevel: Int  // 0-5
    var wrongCount: Int
    var lastReviewedAt: Date?
    var createdAt: Date
}

// WordBook.swift
struct WordBook: Identifiable, Codable {
    let id: String
    var name: String
    var description: String?
    var wordCount: Int
    var isPreset: Bool
    var createdAt: Date
    var updatedAt: Date
}

// GameLevel.swift
struct GameLevel: Identifiable {
    let id: Int
    let bookId: String
    let name: String              // "Level 1: 基础词汇"
    let requiredWords: [String]    // 该关卡的单词ID列表
    let passingScore: Int          // 通关所需正确率 (默认80%)
    let hasBossChallenge: Bool     // 是否有Boss挑战
}
```

---

## 4. 功能模块

### 4.1 单词书管理

**功能列表**:
- 查看所有单词书（预制 + 自定义）
- 创建新单词书（手动添加）
- 编辑单词书信息
- 删除单词书（仅限自定义）
- 导入CSV文件创建单词书

**CSV格式**:
```csv
word,phonetic,meaning,sentence
abandon,əˈbændən,放弃,Never abandon your dreams.
```

### 4.2 预置词库

| 词库名称 | 单词数量 | 难度 |
|----------|----------|------|
| 高中英语3500词 | ~3500 | 基础 |
| 大学英语四级 | ~4500 | 中级 |

**预置词库数据格式**:
```json
{
  "name": "高中英语3500词",
  "description": "高中阶段必备词汇",
  "words": [
    {
      "word": "abandon",
      "phonetic": "əˈbændən",
      "meaning": "vt. 放弃；抛弃",
      "sentence": "Never abandon your dreams."
    }
  ]
}
```

### 4.3 游戏闯关系统

**关卡结构**:
- 每本书分为多个大关（Chapter）
- 每个大关包含3个小关（Stage）
- 每10个单词为一个小关
- 每完成3个小关触发一次Boss挑战

**闯关流程**:
```
开始闯关 → 选择单词书 → 选择关卡
    ↓
关卡1: 10道选择题 (简单)
    ↓ 通过(≥80%)
关卡2: 10道拼写题 (中等)
    ↓ 通过(≥80%)
关卡3: 10道听力题 (较难)
    ↓ 通过(≥80%)
Boss挑战: 混合题型 × 15题
    ↓
下一大关解锁
```

**评分系统**:
- 每题10分
- 100分: ★★★
- 80-99分: ★★
- 60-79分: ★
- <60分: 不通关

### 4.4 学习模式

**三种题型**:

1. **选择题** (Choice)
   - 显示单词，4选1选中文意思
   - 干扰项为同级别难度词汇

2. **拼写题** (Spelling)
   - 显示中文意思和例句
   - 用户拼写单词
   - 支持首字母提示

3. **听力题** (Listening)
   - 播放单词发音
   - 用户选择或拼写单词

**学习流程**:
```
展示单词/例句 → 用户答题 → 即时反馈
    ↓
答对: 掌握度+1，绿色动画
答错: 记录错误次数，红色显示正确答案
    ↓
进入下一题 / 复习错题
```

### 4.5 音频功能

- 使用AVFoundation播放单词发音
- 使用macOS内置say命令生成TTS发音（无网络依赖）
- 或使用预设的在线发音API

---

## 5. UI/UX 设计

### 5.1 导航结构

```
TabView (主导航)
├── 学习 (house.fill)
│   └── NavigationStack
│       ├── 单词书列表
│       ├── 关卡选择
│       └── 游戏闯关
├── 词库管理 (books.vertical)
│   └── NavigationStack
│       ├── 单词书列表
│       ├── 添加单词书
│       └── 单词书详情/编辑
└── 设置 (gear)
    └── NavigationStack
        ├── 声音设置
        ├── 进度重置
        └── 关于
```

### 5.2 色彩系统

```swift
// Color Extension
extension Color {
    static let primaryBlue = Color(hex: "2563EB")
    static let successGreen = Color(hex: "22C55E")
    static let errorRed = Color(hex: "EF4444")
    static let warningOrange = Color(hex: "F59E0B")
    static let backgroundMain = Color(hex: "F8FAFC")
    static let cardBackground = Color.white
}
```

### 5.3 关键界面

**主界面 (MainView)**
- 顶部: 欢迎语 + 今日学习目标
- 中部: 当前进度卡片（显示今日学习单词数、连续天数）
- 底部: Tab导航

**游戏界面 (GameView)**
- 顶部: 关卡名称 + 进度条 + 生命值/分数
- 中央: 题目区域（单词/选项/输入框）
- 底部: 功能按钮（跳过、提示、暂停）

**单词书列表 (WordBookListView)**
- 列表形式展示所有单词书
- 预置词库标记"官方"标签
- 显示进度百分比

---

## 6. 验收标准

### 6.1 功能验收

- [ ] 应用可正常启动，无崩溃
- [ ] 预置词库(高中3500、四级)数据完整导入
- [ ] 可创建自定义单词书
- [ ] 可手动添加单词到词库
- [ ] 可导入CSV文件创建词库
- [ ] 可删除自定义词库
- [ ] 游戏闯关模式正常运行
- [ ] 三种题型(选择/拼写/听力)正常切换
- [ ] 进度保存正确
- [ ] 发音功能正常

### 6.2 视觉验收

- [ ] 界面清晰，层次分明
- [ ] 动画流畅，无明显卡顿
- [ ] 色彩统一，符合设计规范
- [ ] 适配macOS系统深色/浅色模式

### 6.3 性能验收

- [ ] 启动时间 < 3秒
- [ ] 词库切换流畅
- [ ] 大量单词(5000+)列表滚动无卡顿

---

## 7. 技术风险与应对

| 风险 | 等级 | 应对措施 |
|------|------|----------|
| 预置词库数据量大 | 中 | 使用懒加载、分页加载 |
| CSV编码问题 | 中 | 自动检测编码、支持UTF-8/GBK |
| TTS发音质量 | 低 | 使用系统say命令，本地生成 |
| 数据迁移 | 低 | 使用版本号管理数据库结构 |

---

## 8. 开发计划

**Phase 1: 基础架构**
- 项目搭建
- 数据库服务实现
- 基础数据模型

**Phase 2: 单词书管理**
- 词库CRUD功能
- CSV导入
- 预置词库导入

**Phase 3: 游戏核心**
- 闯关流程
- 三种题型
- 进度系统

**Phase 4: 完善优化**
- UI美化
- 动画效果
- 音频功能
