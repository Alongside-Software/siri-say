import Foundation

let version = "1.0.0"

let invocation = CommandLine.arguments
let toolName = URL(fileURLWithPath: invocation.first ?? "siri-say").lastPathComponent
let arguments = Array(invocation.dropFirst())

/// The path is absolute so an installed `say` shim cannot loop back into siri-say.
func handOverToSay() -> Never {
    let executable = "/usr/bin/say"
    var passed: [UnsafeMutablePointer<CChar>?] = (["say"] + arguments).map { strdup($0) }
    passed.append(nil)
    execv(executable, &passed)
    FileHandle.standardError.write(Data("siri-say: could not run /usr/bin/say\n".utf8))
    exit(1)
}

func readStandardInput() -> String {
    String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
}

/// Precedence follows `say`: `-f`, then the words on the command line, then stdin.
func textToSpeak(_ options: Options) -> String {
    if let inputFile = options.inputFile {
        if inputFile == "-" { return readStandardInput() }
        guard let contents = try? String(contentsOfFile: inputFile, encoding: .utf8) else {
            FileHandle.standardError.write(Data("siri-say: could not read \(inputFile)\n".utf8))
            exit(1)
        }
        return contents
    }
    if !options.words.isEmpty { return options.words.joined(separator: " ") }
    return readStandardInput()
}

func printVoices() {
    let siriVoices = Speech.voiceListing()
    if siriVoices.isEmpty {
        print("No Siri voices are installed. Pick one in System Settings > Siri.")
    } else {
        print(siriVoices)
    }
    fflush(stdout)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
    process.arguments = ["-v", "?"]
    try? process.run()
    process.waitUntilExit()
}

func printUsage() {
    print("""
    siri-say \(version) — say, in a Siri voice

    usage: siri-say [-v voice] [-r rate] [-o outfile] [-f infile] [text ...]
           siri-say install [--dir <path>] [--force]
           siri-say uninstall [--dir <path>]
           siri-say voices

    With no -v, it speaks in whichever Siri voice is selected in System Settings.
    -v '?' lists the Siri voices first, then the voices say already knew about.

    Ask for a classic voice, or a flag not listed above, and the call is handed
    to /usr/bin/say unchanged.
    """)
}

if toolName != "say", let first = arguments.first {
    let rest = Array(arguments.dropFirst())
    switch first {
    case "install": exit(Install.run(arguments: rest))
    case "uninstall": exit(Install.uninstall(arguments: rest))
    case "voices":
        printVoices()
        exit(0)
    case "help":
        printUsage()
        exit(0)
    case "version", "--version":
        print("siri-say \(version)")
        exit(0)
    default: break
    }
}

switch CommandLineParser.parse(arguments) {
case .delegate:
    handOverToSay()

case .help:
    printUsage()
    exit(0)

case .listVoices:
    printVoices()
    exit(0)

case .speak(let options):
    let text = textToSpeak(options)
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { exit(0) }

    switch Speech.speak(
        text: text,
        voice: options.voice,
        rate: options.speechRate,
        outputFile: options.outputFile
    ) {
    case .done:
        exit(0)
    case .fallback:
        handOverToSay()
    case .failed(let message):
        FileHandle.standardError.write(Data("siri-say: \(message)\n".utf8))
        exit(1)
    }
}
