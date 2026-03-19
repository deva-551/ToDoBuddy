import Foundation

struct CharacterOption: Identifiable, Equatable {
    let id: String          // DAE filename without extension
    let displayName: String
    let description: String
    let icon: String        // SF Symbol name

    static let none = CharacterOption(id: "none", displayName: "No Buddy", description: "Tasks only, no companion", icon: "list.bullet")

    static let allOptions: [CharacterOption] = [
        .none,
        CharacterOption(id: "sitting_laughing", displayName: "Alex", description: "Always cheerful & laughing", icon: "face.smiling.fill"),
        CharacterOption(id: "sitting_rubbing_arm", displayName: "Jordan", description: "Cool & relaxed", icon: "hand.raised.fill"),
    ]

    static func option(for id: String) -> CharacterOption {
        allOptions.first { $0.id == id } ?? allOptions[0]
    }
}
