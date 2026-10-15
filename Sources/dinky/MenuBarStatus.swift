import DinkyConfig

/// A compact binding-mode indicator, with full names for hover and VoiceOver.
struct MenuBarStatus {
    let title: String
    let description: String

    init(workspace: Int?, mode: String, warning: Bool, enabled: Bool) {
        let number = workspace.map(String.init) ?? "?"
        let prefix = mode == "main" ? "" : mode.first.map { "(\($0.uppercased())) " } ?? ""
        title = prefix + number + (warning ? "!" : "")
        description = "\(AppIdentity.name): Workspace \(number), mode \(mode)"
            + (enabled ? "" : ", disabled") + (warning ? ", warning" : "")
    }
}
