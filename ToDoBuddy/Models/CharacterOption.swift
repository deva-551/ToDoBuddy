import Foundation

struct CharacterOption: Identifiable, Equatable {
    let id: String          // DAE filename without extension
    let displayName: String
    let description: String
    let icon: String        // SF Symbol name

    static let allOptions: [CharacterOption] = [
        CharacterOption(id: "character", displayName: "Catwalk", description: "Walking & turning", icon: "figure.walk"),
        CharacterOption(id: "sitting_clap", displayName: "Clapping", description: "Sitting & clapping", icon: "hands.clap.fill"),
        CharacterOption(id: "sitting_laughing", displayName: "Laughing", description: "Sitting & laughing", icon: "face.smiling.fill"),
        CharacterOption(id: "sitting_rubbing_arm", displayName: "Rubbing Arm", description: "Sitting & rubbing arm", icon: "hand.raised.fill"),
        CharacterOption(id: "sitting_rubbing_arm_medea", displayName: "Rubbing Arm (Alt)", description: "Sitting & rubbing arm", icon: "hand.wave.fill"),
    ]

    static func option(for id: String) -> CharacterOption {
        allOptions.first { $0.id == id } ?? allOptions[0]
    }
}
