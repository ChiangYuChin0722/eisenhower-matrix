import Foundation
import FirebaseFirestore

// MARK: - EisTask ↔ Firestore

extension EisTask {

    var firestoreData: [String: Any] {
        var d: [String: Any] = [
            "id":              id.uuidString,
            "title":           title,
            "notes":           notes,
            "quadrant":        quadrant.rawValue,
            "isCompleted":     isCompleted,
            "createdAt":       Timestamp(date: createdAt),
            "canvasX":         canvasX,
            "canvasY":         canvasY,
            "colorTag":        colorTag.rawValue,
            "colorTagLabel":   colorTagLabel,
            "sortOrder":       sortOrder,
            "isInChecklist":   isInChecklist,
            "recurrence":      recurrence.rawValue,
            "subtasks":        subtasks.map { $0.firestoreData },
        ]
        if let v = dueDate             { d["dueDate"]             = Timestamp(date: v) }
        if let v = completedAt         { d["completedAt"]         = Timestamp(date: v) }
        if let v = checklistCategoryId { d["checklistCategoryId"] = v.uuidString }
        if let v = showInMatrix        { d["showInMatrix"]        = v }
        if let v = tagHex              { d["tagHex"]              = v }
        return d
    }

    static func from(firestoreData data: [String: Any]) -> EisTask? {
        guard
            let idStr = data["id"]       as? String, let id = UUID(uuidString: idStr),
            let title = data["title"]    as? String,
            let qRaw  = data["quadrant"] as? String, let quadrant = Quadrant(rawValue: qRaw)
        else { return nil }

        var t = EisTask(title: title, quadrant: quadrant)
        t.id            = id
        t.notes         = data["notes"]        as? String ?? ""
        t.isCompleted   = data["isCompleted"]  as? Bool   ?? false
        t.canvasX       = data["canvasX"]      as? Double ?? 0.75
        t.canvasY       = data["canvasY"]      as? Double ?? 0.25
        t.colorTag      = TaskColor(rawValue:  data["colorTag"]      as? String ?? "") ?? .none
        t.colorTagLabel = data["colorTagLabel"] as? String ?? ""
        t.sortOrder     = data["sortOrder"]    as? Int    ?? 0
        t.isInChecklist = data["isInChecklist"] as? Bool  ?? false
        t.recurrence    = Recurrence(rawValue: data["recurrence"] as? String ?? "") ?? .none
        t.showInMatrix  = data["showInMatrix"] as? Bool
        t.tagHex        = data["tagHex"]       as? String

        if let ts = data["createdAt"]   as? Timestamp { t.createdAt   = ts.dateValue() }
        if let ts = data["dueDate"]     as? Timestamp { t.dueDate     = ts.dateValue() }
        if let ts = data["completedAt"] as? Timestamp { t.completedAt = ts.dateValue() }
        if let s  = data["checklistCategoryId"] as? String { t.checklistCategoryId = UUID(uuidString: s) }
        if let arr = data["subtasks"] as? [[String: Any]] {
            t.subtasks = arr.compactMap { EisTask.from(firestoreData: $0) }
        }
        return t
    }
}

// MARK: - ChecklistCategory ↔ Firestore

extension ChecklistCategory {

    var firestoreData: [String: Any] {
        ["id": id.uuidString, "name": name, "icon": icon]
    }

    static func from(firestoreData data: [String: Any]) -> ChecklistCategory? {
        guard
            let idStr = data["id"]   as? String, let id = UUID(uuidString: idStr),
            let name  = data["name"] as? String,
            let icon  = data["icon"] as? String
        else { return nil }
        return ChecklistCategory(id: id, name: name, icon: icon)
    }
}
