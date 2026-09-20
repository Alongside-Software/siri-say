import Foundation

enum Install {
    private static let candidateDirectories = ["/usr/local/bin", "\(NSHomeDirectory())/.local/bin"]

    /// A copy already somewhere that beats `/usr/bin` on PATH — where Homebrew puts
    /// it — stays put and only gains the shim.
    ///
    /// The unresolved directory is tried first: Homebrew keeps the binary in the
    /// Cellar and links it onto PATH, so resolving the link lands somewhere PATH
    /// has never heard of.
    private static func defaultDirectory() -> String? {
        let manager = FileManager.default
        if let current = Bundle.main.executablePath {
            let homes = [
                (current as NSString).deletingLastPathComponent,
                ((current as NSString).resolvingSymlinksInPath as NSString).deletingLastPathComponent
            ]
            for home in homes where manager.isWritableFile(atPath: home) && comesBeforeSystemBin(home) {
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

            // Copy what the executable really is. Homebrew's copy on PATH is a
            // relative symlink into the Cellar, which would dangle anywhere else.
            // Both sides are standardized, or a /private prefix on one of them
            // reads as a different file and the copy clobbers the link in place.
            let realSource = (source as NSString).resolvingSymlinksInPath
            let destination = (toolPath as NSString).standardizingPath
            if (source as NSString).standardizingPath != destination
                && (realSource as NSString).standardizingPath != destination {
                if manager.fileExists(atPath: toolPath) { try manager.removeItem(atPath: toolPath) }
                try manager.copyItem(atPath: realSource, toPath: toolPath)
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
            // Install only ever writes a real file here, so a symlink is somebody
            // else's — Homebrew's link onto PATH — and is left for them to remove.
            let isLink = (try? manager.destinationOfSymbolicLink(atPath: toolPath)) != nil
            if manager.fileExists(atPath: toolPath) && !isLink {
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
        let wanted = (directory as NSString).standardizingPath
        guard let ours = entries.firstIndex(where: { ($0 as NSString).standardizingPath == wanted }) else {
            return false
        }
        guard let system = entries.firstIndex(of: "/usr/bin") else { return true }
        return ours < system
    }

    private static func complain(_ message: String) {
        FileHandle.standardError.write(Data("siri-say: \(message)\n".utf8))
    }
}
