import Foundation
import SwiftUI

// MARK: - Matrix colour themes

struct MatrixTheme: Identifiable {
    let id: String
    let nameEN: String
    let nameZH: String
    let doFirst: Color
    let schedule: Color
    let delegateQ: Color   // 'delegate' is a Swift keyword
    let eliminate: Color
    let accentId: String   // drives app-wide accent when theme is chosen

    func color(for quadrant: Quadrant) -> Color {
        switch quadrant {
        case .doFirst:   return doFirst
        case .schedule:  return schedule
        case .delegate:  return delegateQ
        case .eliminate: return eliminate
        }
    }
    func bgColor(for quadrant: Quadrant) -> Color {
        color(for: quadrant).opacity(0.07)
    }
}

let matrixThemes: [MatrixTheme] = [
    MatrixTheme(id: "classic",  nameEN: "Classic",  nameZH: "經典",
        doFirst:  Color(red: 0.85, green: 0.22, blue: 0.22),
        schedule: Color(red: 0.20, green: 0.44, blue: 0.85),
        delegateQ:Color(red: 0.92, green: 0.55, blue: 0.14),
        eliminate:Color(red: 0.36, green: 0.36, blue: 0.38),
        accentId: "red"),

    MatrixTheme(id: "ocean",    nameEN: "Ocean",    nameZH: "海洋",
        doFirst:  Color(red: 0.00, green: 0.50, blue: 0.70),
        schedule: Color(red: 0.10, green: 0.32, blue: 0.78),
        delegateQ:Color(red: 0.00, green: 0.68, blue: 0.78),
        eliminate:Color(red: 0.35, green: 0.48, blue: 0.58),
        accentId: "teal"),

    MatrixTheme(id: "forest",   nameEN: "Forest",   nameZH: "森林",
        doFirst:  Color(red: 0.12, green: 0.52, blue: 0.18),
        schedule: Color(red: 0.08, green: 0.38, blue: 0.12),
        delegateQ:Color(red: 0.55, green: 0.70, blue: 0.18),
        eliminate:Color(red: 0.42, green: 0.50, blue: 0.35),
        accentId: "green"),

    MatrixTheme(id: "sunset",   nameEN: "Sunset",   nameZH: "夕陽",
        doFirst:  Color(red: 0.90, green: 0.22, blue: 0.18),
        schedule: Color(red: 0.62, green: 0.18, blue: 0.68),
        delegateQ:Color(red: 0.96, green: 0.56, blue: 0.10),
        eliminate:Color(red: 0.54, green: 0.34, blue: 0.28),
        accentId: "orange"),

    MatrixTheme(id: "pastel",   nameEN: "Pastel",   nameZH: "粉彩",
        doFirst:  Color(red: 0.94, green: 0.48, blue: 0.52),
        schedule: Color(red: 0.50, green: 0.68, blue: 0.96),
        delegateQ:Color(red: 0.98, green: 0.76, blue: 0.44),
        eliminate:Color(red: 0.68, green: 0.68, blue: 0.74),
        accentId: "pink"),

    MatrixTheme(id: "candy",    nameEN: "Candy",    nameZH: "糖果",
        doFirst:  Color(red: 0.96, green: 0.18, blue: 0.58),
        schedule: Color(red: 0.22, green: 0.50, blue: 0.96),
        delegateQ:Color(red: 0.20, green: 0.82, blue: 0.50),
        eliminate:Color(red: 0.65, green: 0.30, blue: 0.90),
        accentId: "purple"),

    MatrixTheme(id: "mono",     nameEN: "Mono",     nameZH: "單色",
        doFirst:  Color(red: 0.12, green: 0.12, blue: 0.12),
        schedule: Color(red: 0.33, green: 0.33, blue: 0.33),
        delegateQ:Color(red: 0.54, green: 0.54, blue: 0.54),
        eliminate:Color(red: 0.70, green: 0.70, blue: 0.70),
        accentId: "blue"),
]

extension Quadrant {
    /// Returns the theme-aware color for this quadrant.
    func color(theme: String) -> Color {
        matrixThemes.first { $0.id == theme }?.color(for: self) ?? self.color
    }
    func bgColor(theme: String) -> Color {
        color(theme: theme).opacity(0.07)
    }
}

struct AccentOption: Identifiable {
    let id: String   // stored in AppStorage
    let color: Color
    let labelEN: String
    let labelZH: String
}

let accentOptions: [AccentOption] = [
    AccentOption(id: "blue",   color: .blue,   labelEN: "Blue",   labelZH: "藍"),
    AccentOption(id: "indigo", color: .indigo, labelEN: "Indigo", labelZH: "靛"),
    AccentOption(id: "purple", color: .purple, labelEN: "Purple", labelZH: "紫"),
    AccentOption(id: "pink",   color: .pink,   labelEN: "Pink",   labelZH: "粉"),
    AccentOption(id: "red",    color: .red,    labelEN: "Red",    labelZH: "紅"),
    AccentOption(id: "orange", color: .orange, labelEN: "Orange", labelZH: "橘"),
    AccentOption(id: "yellow", color: Color(red: 0.85, green: 0.70, blue: 0.0), labelEN: "Yellow", labelZH: "黃"),
    AccentOption(id: "green",  color: .green,  labelEN: "Green",  labelZH: "綠"),
    AccentOption(id: "teal",   color: .teal,   labelEN: "Teal",   labelZH: "青"),
    AccentOption(id: "mint",   color: .mint,   labelEN: "Mint",   labelZH: "薄荷"),
]

extension Color {
    static func accent(_ name: String) -> Color {
        accentOptions.first { $0.id == name }?.color ?? .blue
    }

    /// White in light mode, system grouped background in dark mode.
    static let appBackground = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? .systemGroupedBackground
            : .systemBackground
    })
}

/// Build a string set from a language code ("en" or "zh").
/// Usage in any view:
///   @AppStorage("appLanguage") private var lang: String = "en"
///   private var s: Str { Str(lang) }
struct Str {
    let zh: Bool
    init(_ lang: String = UserDefaults.standard.string(forKey: "appLanguage") ?? "en") {
        zh = lang == "zh"
    }

    // MARK: - Common actions
    var add:    String { zh ? "新增" : "Add" }
    var save:   String { zh ? "儲存" : "Save" }
    var cancel: String { zh ? "取消" : "Cancel" }
    var done:   String { zh ? "完成" : "Done" }
    var undo:   String { zh ? "還原" : "Undo" }
    var delete: String { zh ? "刪除" : "Delete" }
    var edit:   String { zh ? "編輯" : "Edit" }
    var today:  String { zh ? "今天" : "Today" }
    var addTask: String { zh ? "新增任務" : "Add Task" }

    // MARK: - Tabs
    var tabMatrix:    String { zh ? "矩陣"     : "Matrix" }
    var tabChecklist: String { zh ? "清單"     : "Checklist" }
    var tabCalendar:  String { zh ? "行事曆"   : "Calendar" }
    var tabDeadlines: String { zh ? "截止日期" : "Deadlines" }
    var tabDashboard: String { zh ? "總覽"     : "Dashboard" }

    // MARK: - MatrixView
    var matrixNavTitle:    String { zh ? "艾森豪矩陣"  : "Eisenhower Matrix" }
    var notUrgentLabel:    String { zh ? "← 不緊急"   : "← Not Urgent" }
    var urgentLabel:       String { zh ? "緊急 →"     : "Urgent →" }
    var importantLabel:    String { zh ? "重要 ↑"     : "Important ↑" }
    var notImportantLabel: String { zh ? "↓ 不重要"   : "↓ Not Important" }
    var tapToAdd:          String { zh ? "點擊任意處新增" : "tap anywhere to add" }

    // MARK: - ChecklistView
    var hideDone:              String { zh ? "隱藏完成"   : "Hide done" }
    var showDone:              String { zh ? "顯示完成"   : "Show done" }
    var quickAddPlaceholder:   String { zh ? "快速新增..." : "Quick add item…" }
    var allCategory:           String { zh ? "全部"      : "All" }
    var newList:               String { zh ? "新清單"     : "New List" }
    var listNameLabel:         String { zh ? "清單名稱"   : "List Name" }
    var iconLabel:             String { zh ? "圖示"      : "Icon" }
    var egGroceries:           String { zh ? "例如：購物" : "e.g. Groceries" }
    var emptyChecklistTitle:   String { zh ? "清單是空的" : "Your checklist is empty" }
    var emptyChecklistSub:     String { zh ? "在下方輸入快速新增\n或點 + 新增完整任務" : "Type below to quickly add an item,\nor tap + to add a full task." }
    var emptyCategoryMsg:      String { zh ? "此清單沒有項目" : "No items in this list" }

    // MARK: - CalendarView
    var monthMode:       String { zh ? "月" : "Month" }
    var weekMode:        String { zh ? "週" : "Week" }
    var dayMode:         String { zh ? "日" : "Day" }
    var allDay:          String { zh ? "全天" : "All Day" }
    var timeline:        String { zh ? "時間軸" : "Timeline" }
    var noTasksForDay:   String { zh ? "今天沒有任務" : "No tasks for this day" }
    func taskCount(_ n: Int) -> String {
        zh ? "\(n) 個任務" : "\(n) task\(n == 1 ? "" : "s")"
    }

    // MARK: - DeadlineView
    var showDoneTitle:   String { zh ? "顯示完成" : "Show Done" }
    var hideDoneTitle:   String { zh ? "隱藏完成" : "Hide Done" }
    var overdue:         String { zh ? "逾期"     : "Overdue" }
    var tomorrow:        String { zh ? "明天"     : "Tomorrow" }
    var thisWeek:        String { zh ? "本週"     : "This Week" }
    var later:           String { zh ? "之後"     : "Later" }
    var noDeadlines:     String { zh ? "沒有截止日期" : "No deadlines" }
    var noDeadlinesSub:  String { zh ? "為任務設定截止日\n在這裡追蹤進度" : "Add due dates to tasks to track\nthem here." }
    var addWithDeadline: String { zh ? "新增有截止日的任務" : "Add Task with Deadline" }
    var allDoneMsg:      String { zh ? "所有任務已完成！" : "All tasks completed!" }
    var nextDeadline:    String { zh ? "最近截止日" : "Next Deadline" }
    func inDays(_ n: Int) -> String { zh ? "還有 \(n) 天" : "In \(n) days" }

    // MARK: - DashboardView
    var overallProgress:   String { zh ? "整體進度"  : "Overall Progress" }
    var lastSevenDays:     String { zh ? "最近 7 天" : "Last 7 Days" }
    var quadrantBreakdown: String { zh ? "象限分析"  : "Quadrant Breakdown" }
    var recentTasks:       String { zh ? "最近任務"  : "Recent Tasks" }
    var totalLabel:        String { zh ? "總計"      : "Total" }
    var pendingLabel:      String { zh ? "待完成"    : "Pending" }
    var completedLabel:    String { zh ? "已完成"    : "Completed" }
    var streakKeepUp:      String { zh ? "繼續保持！今天完成一個任務！" : "Keep it up — complete a task today!" }
    var streakStart:       String { zh ? "今天完成一個任務，開始連續紀錄" : "Complete a task today to start your streak" }
    func tasksDone(_ c: Int, _ t: Int) -> String {
        zh ? "\(c) / \(t) 已完成" : "\(c) of \(t) tasks done"
    }
    func streak(_ n: Int) -> String {
        zh ? "\(n) 天連續" : "\(n) day\(n == 1 ? "" : "s") streak"
    }

    // MARK: - SettingsView
    var settingsTitle:      String { zh ? "設定"   : "Settings" }
    var displaySection:     String { zh ? "顯示"   : "Display" }
    var showCompletedLabel: String { zh ? "顯示已完成任務" : "Show completed tasks" }
    var themeLabel:         String { zh ? "外觀"   : "Theme" }
    var themeSystem:        String { zh ? "系統"   : "System" }
    var themeLight:         String { zh ? "淺色"   : "Light" }
    var themeDark:          String { zh ? "深色"   : "Dark" }
    var languageSection:    String { zh ? "語言"   : "Language" }
    var notifSection:       String { zh ? "通知"   : "Notifications" }
    var notifReminders:     String { zh ? "任務提醒" : "Task reminders" }
    var notifOn:            String { zh ? "開啟"   : "On" }
    var notifOff:           String { zh ? "關閉"   : "Off" }
    var notifNotSet:        String { zh ? "未設定" : "Not set" }
    var enableNotif:        String { zh ? "開啟通知" : "Enable Notifications" }
    var openSettingsNotif:  String { zh ? "前往設定開啟" : "Open Settings to Enable" }
    var notifDesc:          String { zh ? "任務截止前 1 小時會收到提醒。" : "You'll get a reminder 1 hour before each task's due time." }
    var aboutSection:       String { zh ? "矩陣說明" : "About the Matrix" }
    var statsSection:       String { zh ? "統計"   : "Statistics" }
    var totalTasksLabel:    String { zh ? "總任務數" : "Total tasks" }
    var completionRateLabel:String { zh ? "完成率"  : "Completion rate" }
    var currentStreakLabel:  String { zh ? "連續天數" : "Current streak" }
    var resetSectionTitle:  String { zh ? "重置"   : "Reset" }
    var resetButton:        String { zh ? "重置 App 資料" : "Reset App Data" }
    var resetConfirmTitle:  String { zh ? "重置 App 資料？" : "Reset app data?" }
    var resetConfirmMsg:    String { zh ? "所有任務將被刪除，並還原成範例資料。" : "All tasks will be deleted and sample data restored." }
    var resetConfirmAction: String { zh ? "重置" : "Reset" }
    var doneButton:         String { zh ? "完成" : "Done" }
    var accentSection:       String { zh ? "主題色"  : "Accent Color" }
    var matrixThemeSection:  String { zh ? "象限色系" : "Matrix Colors" }
    func themeName(_ id: String) -> String {
        guard let t = matrixThemes.first(where: { $0.id == id }) else { return id }
        return zh ? t.nameZH : t.nameEN
    }

    // MARK: - Onboarding
    var skip:       String { zh ? "略過" : "Skip" }
    var next:       String { zh ? "繼續" : "Next" }
    var getStarted: String { zh ? "開始使用" : "Get Started" }
    var onboardWelcomeTitle: String { zh ? "Eisenhower 矩陣" : "Eisenhower Matrix" }
    var onboardWelcomeSub:   String { zh ? "用緊急與重要性整理你的任務，聚焦在真正重要的事。" : "Organize tasks by urgency and importance.\nFocus on what truly matters." }
    var onboardMatrixTitle:  String { zh ? "四個象限" : "Four Quadrants" }
    var onboardMatrixSub:    String { zh ? "每個任務都屬於其中一個象限。拖曳方塊到對應位置。" : "Every task belongs in one of four quadrants.\nDrag dots to reposition them." }
    var onboardFeatTitle:    String { zh ? "功能一覽" : "Everything You Need" }
    var onboardStartTitle:   String { zh ? "準備好了！" : "You're all set!" }
    var onboardStartSub:     String { zh ? "開始整理你的任務，讓每一天更有效率。" : "Start organizing your tasks and make every day more productive." }
    var onboardFeatureCalendar:  String { zh ? "用月曆與時間軸檢視有期限的任務" : "Monthly & timeline views for scheduled tasks" }
    var onboardFeatureDeadlines: String { zh ? "依日期分組追蹤截止任務" : "Deadline tracking grouped by urgency" }
    var onboardFeatureChecklist: String { zh ? "多個清單、子任務、備註一次管理" : "Multiple lists with subtasks & notes" }
    var onboardFeatureDashboard: String { zh ? "完成率、連續天數與象限統計一覽" : "Streaks, completion rates & quadrant stats" }

    // MARK: - Checklist extras (reorder / subtasks)
    var doneReorder: String { zh ? "完成" : "Done" }
    func subtasksOf(_ done: Int, _ total: Int) -> String {
        zh ? "\(done)/\(total) 子任務" : "\(done)/\(total) subtasks"
    }

    // MARK: - Custom quadrant names
    var customQuadrantSection:  String { zh ? "自訂象限名稱" : "Custom Quadrant Names" }
    var quadrantNamePlaceholder:String { zh ? "預設" : "Default" }

    // MARK: - Pomodoro
    var pomodoroTitle:       String { zh ? "專注計時" : "Focus Timer" }
    var pomodoroSection:     String { zh ? "專注計時器" : "Focus Timer" }
    var focusMode:           String { zh ? "專注" : "Focus" }
    var shortBreakLabel:     String { zh ? "短休息" : "Short Break" }
    var longBreakLabel:      String { zh ? "長休息" : "Long Break" }
    var workDuration:        String { zh ? "專注時長" : "Work Duration" }
    var shortBreakDuration:  String { zh ? "短休息時長" : "Short Break" }
    var longBreakDuration:   String { zh ? "長休息時長" : "Long Break" }
    var focusLabel:          String { zh ? "專注" : "Focus" }
    var sessionLabel:        String { zh ? "回合" : "Sessions" }

    // MARK: - AddTaskView
    var newTaskTitle:      String { zh ? "新增任務"  : "New Task" }
    var editTaskTitle:     String { zh ? "編輯任務"  : "Edit Task" }
    var taskSection:       String { zh ? "任務"      : "Task" }
    var titleField:        String { zh ? "標題"      : "Title" }
    var notesField:        String { zh ? "備註（選填）" : "Notes (optional)" }
    var quadrantSection:   String { zh ? "象限"      : "Quadrant" }
    var addToCalendar:     String { zh ? "加入行事曆" : "Add to Calendar" }
    var dateTimeLabel:     String { zh ? "日期與時間" : "Date & Time" }
    var repeatLabel:       String { zh ? "重複"      : "Repeat" }
    var addToChecklist:    String { zh ? "加入清單"  : "Add to Checklist" }
    var listPickerLabel:   String { zh ? "清單"      : "List" }
    var colorTagSection:   String { zh ? "顏色標籤"  : "Color Tag" }
    var colorTagLabelField: String { zh ? "標籤文字（選填）" : "Label (optional)" }
    var subtasksSection:   String { zh ? "子任務"    : "Subtasks" }
    var addSubtask:        String { zh ? "新增子任務..." : "Add subtask…" }

    // MARK: - Quadrant names (localized)
    func quadrantTitle(_ q: Quadrant) -> String {
        let custom = UserDefaults.standard.string(forKey: "quadrantName_\(q.rawValue)") ?? ""
        if !custom.isEmpty { return custom }
        return quadrantDefaultTitle(q)
    }
    /// Returns the built-in default name (ignores user customisation).
    func quadrantDefaultTitle(_ q: Quadrant) -> String {
        guard zh else { return q.title }
        switch q {
        case .doFirst:   return "立刻執行"
        case .schedule:  return "計畫安排"
        case .delegate:  return "委派他人"
        case .eliminate: return "排除刪去"
        }
    }
    func quadrantSubtitle(_ q: Quadrant) -> String {
        guard zh else { return q.subtitle }
        switch q {
        case .doFirst:   return "緊急且重要"
        case .schedule:  return "重要但不緊急"
        case .delegate:  return "緊急但不重要"
        case .eliminate: return "不緊急也不重要"
        }
    }
}
