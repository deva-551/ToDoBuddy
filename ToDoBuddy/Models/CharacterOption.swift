import Foundation

struct CharacterOption: Identifiable, Equatable {
    let id: String          // DAE filename without extension
    let displayName: String
    let description: String
    let icon: String        // SF Symbol name

    static let none = CharacterOption(id: "none", displayName: "No Buddy", description: "Tasks only, no companion", icon: "list.bullet")

    static let allOptions: [CharacterOption] = [
        .none,
        CharacterOption(id: "angry", displayName: "Alex", description: "Feisty & fired up", icon: "flame.fill"),
        CharacterOption(id: "sitting", displayName: "Zoya", description: "Calm & composed", icon: "figure.seated.side"),
    ]

    static func option(for id: String) -> CharacterOption {
        allOptions.first { $0.id == id } ?? allOptions[0]
    }
}
