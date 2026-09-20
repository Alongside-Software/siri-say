import Foundation

enum Install {
    private static let candidateDirectories = ["/usr/local/bin", "\(NSHomeDirectory())/.local/bin"]

    /// A copy already somewhere that beats `/usr/bin` on PATH — where Homebrew puts
    /// it — stays put and only gains the shim.
    private static func defaultDirectory() -> String? {
        if let current = Bundle.main.executablePath {
            let home = ((current as NSString).resolvingSymlinksInPath as NSString).deletingLastPathComponent
            if FileManager.default.isWritableFile(atPath: home) && comesBeforeSystemBin(home) {
                return home
            }
        }
        return writableDirectory()
    }

    /// `/usr/bin/say` is SIP-protected and cannot be replaced, so the shim is a
    /// `say` symlink in a directory earlier on PATH.
    static func run(arguments: [String]) -> Int32 {
        var directory: String?
        var force = false
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--dir":
                index += 1
                guard index < arguments.count else {
                    complain("--dir needs a directory")
                    return 1
                }
                directory = arguments[index]
            case "--force":
                force = true
            default:
                complain("unknown install option: \(arguments[index])")
                return 1
            }
            index += 1
        }

        guard let source = Bundle.main.executablePath else {
            complain("could not find my own executable")
            return 1
        }

        guard let target = directory ?? defaultDirectory() else {
            complain("no writable install directory; try: siri-say install --dir ~/bin")
            return 1
        }

        let manager = FileManager.default
        let expanded = (target as NSString).expandingTildeInPath
        let toolPath = expanded + "/siri-say"
        let shimPath = expanded + "/say"

        do {
            try manager.createDirectory(atPath: expanded, withIntermediateDirectories: true)

            if (source as NSString).standardizingPath != toolPath {
                if manager.fileExists(atPath: toolPath) { try manager.removeItem(atPath: toolPath) }
                try manager.copyItem(atPath: source, toPath: toolPath)
                try manager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: toolPath)
            }

            if let existing = try? manager.destinationOfSymbolicLink(atPath: shimPath) {
                if existing != "siri-say" && existing != toolPath && !force {
                    complain("\(shimPath) already points at \(existing); re-run with --force to replace it")
                    return 1
                }
                try manager.removeItem(atPath: shimPath)
            } else if manager.fileExists(atPath: shimPath) {
                guard force else {
                    complain("\(shimPath) already exists; re-run with --force to replace it")
                    return 1
                }
                try manager.removeItem(atPath: shimPath)
            }

            try manager.createSymbolicLink(atPath: shimPath, withDestinationPath: "siri-say")
        } catch {
            complain("install failed: \(error.localizedDescription)")
            return 1
        }

        print("installed \(toolPath)")
        print("linked    \(shimPath) -> siri-say")

        if !comesBeforeSystemBin(expanded) {
            print("")
            print("warning: \(expanded) is not ahead of /usr/bin on your PATH, so `say` still")
            print("         runs Apple's copy. Add this to your shell profile:")
            print("         export PATH=\"\(expanded):$PATH\"")
        }

        return 0
    }

    static func uninstall(arguments: [String]) -> Int32 {
        var directory: String?
        var index = 0

        while index < arguments.count {
            if arguments[index] == "--dir" {
                index += 1
                guard index < arguments.count else {
                    complain("--dir needs a directory")
                    return 1
                }
                directory = arguments[index]
            } else {
                complain("unknown uninstall option: \(arguments[index])")
                return 1
            }
            index += 1
        }

        let manager = FileManager.default
        let directories = directory.map { [($0 as NSString).expandingTildeInPath] } ?? candidateDirectories
        var removed = false

        for candidate in directories {
            let toolPath = candidate + "/siri-say"
            let shimPath = candidate + "/say"

            if let destination = try? manager.destinationOfSymbolicLink(atPath: shimPath),
               destination == "siri-say" || destination == toolPath {
                try? manager.removeItem(atPath: shimPath)
                print("removed   \(shimPath)")
                removed = true
            }
            if manager.fileExists(atPath: toolPath) {
                try? manager.removeItem(atPath: toolPath)
                print("removed   \(toolPath)")
                removed = true
            }
        }

        if !removed { print("nothing to remove") }
        return 0
    }

    private static func writableDirectory() -> String? {
        let manager = FileManager.default
        for candidate in candidateDirectories {
            if manager.isWritableFile(atPath: candidate) { return candidate }
            if !manager.fileExists(atPath: candidate) {
                let parent = (candidate as NSString).deletingLastPathComponent
                if manager.isWritableFile(atPath: parent) { return candidate }
            }
        }
        return nil
    }

    private static func comesBeforeSystemBin(_ directory: String) -> Bool {
        let entries = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        guard let ours = entries.firstIndex(where: { ($0 as NSString).standardizingPath == directory }) else {
            return false
        }
        guard let system = entries.firstIndex(of: "/usr/bin") else { return true }
        return ours < system
    }

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data("siri-say: \(message)\n".utf8))
    }
}
