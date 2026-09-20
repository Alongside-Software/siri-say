import Foundation

struct SystemSiriVoice {
    /// Short name as Siri records it, e.g. `gordon`.
    let name: String
    /// BCP-47, e.g. `en-AU`.
    let language: String
}

enum Speech {
    enum Outcome {
        case done
        /// No Siri voice matched, so nothing was spoken and `say` should take over.
        case fallback
        case failed(String)
    }

    /// Siri keeps the System Settings choice in an `Output Voice` dictionary in
    /// the `com.apple.assistant.backedup` domain.
    static func systemVoice() -> SystemSiriVoice? {
        guard let preferences = CFPreferencesCopyAppValue(
            "Output Voice" as CFString,
            "com.apple.assistant.backedup" as CFString
        ) as? [String: Any] else { return nil }

        guard let name = preferences["Name"] as? String, !name.isEmpty else { return nil }
        let language = preferences["Language"] as? String ?? ""
        return SystemSiriVoice(name: name, language: language)
    }

    /// One line per Siri voice and per enhanced-or-better voice from the old engine.
    static func voiceListing() -> String {
        let result = runScript(arguments: ["list", "", "", "", "", "", ""])
        guard result.status == 0 else { return "" }
        return result.output.trimmingCharacters(in: .newlines)
    }

    static func speak(text: String, voice: String?, rate: Float?, outputFile: String?) -> Outcome {
        let system = systemVoice()
        let result = runScript(arguments: [
            "speak",
            voice ?? "",
            system?.name ?? "",
            system?.language ?? "",
            rate.map { String($0) } ?? "",
            encode(outputFile),
            encode(text)
        ])

        if result.status != 0 {
            let message = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failed(message.isEmpty ? "osascript exited \(result.status)" : message)
        }
        if result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "FALLBACK" {
            return .fallback
        }
        return .done
    }

    /// osascript reads any argument starting with a dash as one of its own options,
    /// and newlines do not survive the trip, so arguments travel base64-encoded.
    private static func encode(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "" }
        return Data(value.utf8).base64EncodedString()
    }

    private static func runScript(arguments: [String]) -> (status: Int32, output: String, error: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-l", "JavaScript", "-"] + arguments

        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            return (1, "", "could not run osascript: \(error.localizedDescription)")
        }

        input.fileHandleForWriting.write(Data(SpeechScript.source.utf8))
        input.fileHandleForWriting.closeFile()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (
            process.terminationStatus,
            String(decoding: outputData, as: UTF8.self),
            String(decoding: errorData, as: UTF8.self)
        )
    }
}
