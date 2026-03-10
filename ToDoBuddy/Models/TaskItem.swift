import Foundation

struct TaskItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var date: String // "yyyy-MM-dd"
    var sortOrder: Int
    var completedAt: Date?
}
