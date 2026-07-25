enum AppLaunchMode: Equatable {
    case foreground
    case background

    init(arguments: [String]) {
        self = arguments.contains("--background") ? .background : .foreground
    }
}
