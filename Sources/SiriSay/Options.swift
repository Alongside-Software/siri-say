import Foundation

struct Options {
    var voice: String?
    var rateWordsPerMinute: Double?
    var outputFile: String?
    var inputFile: String?
    var words: [String] = []

    private static let defaultWordsPerMinute = 175.0

    /// AVSpeechUtterance publishes no words-per-minute mapping, so this pins
    /// `say`'s default of 175 wpm to its 0.5 midpoint and scales from there.
    var speechRate: Float? {
        guard let rateWordsPerMinute else { return nil }
        let scaled = 0.5 * rateWordsPerMinute / Options.defaultWordsPerMinute
        return Float(min(max(scaled, 0.02), 1.0))
    }
}

enum Command {
    case speak(Options)
    case listVoices
    case help
    /// A flag siri-say does not implement — hand the whole command line to `say`.
    case delegate
}

enum CommandLineParser {
    private static let valueFlags: Set<String> = [
        "-v", "--voice", "-r", "--rate", "-o", "--output-file", "-f", "--input-file"
    ]

    /// Anything siri-say does not implement — `--progress`, `-i`, the audio format
    /// flags — comes back as `.delegate`, for the real `say` to handle unchanged.
    static func parse(_ arguments: [String]) -> Command {
        var options = Options()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            if argument == "--" {
                options.words.append(contentsOf: arguments[(index + 1)...])
                break
            }

            if argument == "-?" || argument == "-h" || argument == "--help" {
                return .help
            }

            // --flag=value is only valid for the long flags say itself spells out.
            var flag = argument
            var attachedValue: String?
            if argument.hasPrefix("--"), let separator = argument.firstIndex(of: "=") {
                flag = String(argument[argument.startIndex..<separator])
                attachedValue = String(argument[argument.index(after: separator)...])
            }

            if valueFlags.contains(flag) {
                guard let value = attachedValue ?? arguments[safe: index + 1] else { return .delegate }
                if attachedValue == nil { index += 1 }

                switch flag {
                case "-v", "--voice":
                    if value == "?" { return .listVoices }
                    options.voice = value
                case "-r", "--rate":
                    guard let rate = Double(value), rate > 0 else { return .delegate }
                    options.rateWordsPerMinute = rate
                case "-o", "--output-file":
                    options.outputFile = value
                case "-f", "--input-file":
                    options.inputFile = value
                default:
                    return .delegate
                }

                index += 1
                continue
            }

            if argument.hasPrefix("-") && argument.count > 1 {
                return .delegate
            }

            options.words.append(argument)
            index += 1
        }

        return .speak(options)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
