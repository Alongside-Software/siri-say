import Foundation

/// The JXA program that does the speaking, kept as source because it has to run
/// somewhere else. `AVSpeechSynthesisVoice.speechVoices()` hides the Siri voices
/// from any process Apple did not sign — this binary sees 182 voices, osascript
/// sees 196 — and no entitlement or Developer ID signature changes that. So
/// siri-say parses the command line and osascript speaks.
///
/// Run as: osascript -l JavaScript - <mode> <voice> <systemName> <systemLanguage> <rate> <outputBase64> <textBase64>
/// Prints `FALLBACK` and speaks nothing when no Siri voice matches the request.
enum SpeechScript {
    static let source = #"""
ObjC.import('AVFoundation')

var SIRI_PREFIX = 'com.apple.siri.'

function pump(seconds) {
  $.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.dateWithTimeIntervalSinceNow(seconds))
}

function decode(encoded) {
  if (!encoded) return ''
  var data = $.NSData.alloc.initWithBase64EncodedStringOptions(encoded, 0)
  return ObjC.unwrap($.NSString.alloc.initWithDataEncoding(data, $.NSUTF8StringEncoding))
}

function siriVoices() {
  var all = $.AVSpeechSynthesisVoice.speechVoices
  var count = all.count
  var found = []
  for (var i = 0; i < count; i++) {
    var voice = all.objectAtIndex(i)
    var identifier = ObjC.unwrap(voice.identifier)
    if (identifier.indexOf(SIRI_PREFIX) !== 0) continue
    found.push({
      voice: voice,
      identifier: identifier,
      shortName: identifier.split('.').pop(),
      language: ObjC.unwrap(voice.language)
    })
  }
  return found
}

function wantedMatches(candidate, wanted) {
  var lowered = wanted.toLowerCase()
  return candidate.identifier.toLowerCase() === lowered || candidate.shortName.toLowerCase() === lowered
}

function resolve(wanted, systemName, systemLanguage) {
  var voices = siriVoices()
  if (voices.length === 0) return null

  if (wanted) {
    for (var i = 0; i < voices.length; i++) {
      if (wantedMatches(voices[i], wanted)) return voices[i]
    }
    return null
  }

  if (systemName) {
    for (var j = 0; j < voices.length; j++) {
      if (voices[j].shortName.toLowerCase() === systemName.toLowerCase()) return voices[j]
    }
  }
  if (systemLanguage) {
    for (var k = 0; k < voices.length; k++) {
      if (voices[k].language === systemLanguage) return voices[k]
    }
  }
  return voices[0]
}

function pad(text, width) {
  var padded = text
  while (padded.length < width) padded += ' '
  return padded
}

function listing() {
  var all = $.AVSpeechSynthesisVoice.speechVoices
  var rows = []
  for (var i = 0; i < all.count; i++) {
    var voice = all.objectAtIndex(i)
    // AVSpeechSynthesisVoiceQuality is 1-based: 1 default, 2 enhanced, 3 premium.
    // Everything below enhanced is eloquence, super-compact or a novelty voice.
    if (voice.quality < 2) continue
    var identifier = ObjC.unwrap(voice.identifier)
    var siri = identifier.indexOf(SIRI_PREFIX) === 0
    rows.push({
      siri: siri,
      // Every Siri voice is named "Voice 1"; the identifier carries the real one.
      // Other names are printed as `say -v '?'` spells them, so they can be copied.
      name: siri ? identifier.split('.').pop() : ObjC.unwrap(voice.name),
      language: ObjC.unwrap(voice.language)
    })
  }

  rows.sort(function (a, b) {
    if (a.siri !== b.siri) return a.siri ? -1 : 1
    return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
  })

  var lines = []
  for (var j = 0; j < rows.length; j++) {
    lines.push(pad(rows[j].name, 20) + pad(rows[j].language, 9) +
      (rows[j].siri ? 'Siri' : 'enhanced (via say)'))
  }
  return lines.join('\n')
}

function speakAloud(utterance) {
  var synthesizer = $.AVSpeechSynthesizer.alloc.init
  synthesizer.speakUtterance(utterance)
  for (var waited = 0; waited < 3 && !synthesizer.isSpeaking; waited += 0.05) pump(0.05)
  while (synthesizer.isSpeaking) pump(0.1)
  pump(0.2)
}

function writeToFile(utterance, path) {
  var synthesizer = $.AVSpeechSynthesizer.alloc.init
  var audioFile = null
  var finished = false
  var failure = null

  synthesizer.writeUtteranceToBufferCallback(utterance, function (buffer) {
    try {
      if (buffer.frameLength === 0) {
        finished = true
        return
      }
      if (!audioFile) {
        audioFile = $.AVAudioFile.alloc.initForWritingSettingsCommonFormatInterleavedError(
          $.NSURL.fileURLWithPath(path),
          buffer.format.settings,
          buffer.format.commonFormat,
          buffer.format.isInterleaved,
          $()
        )
      }
      audioFile.writeFromBufferError(buffer, $())
    } catch (error) {
      failure = String(error)
      finished = true
    }
  })

  for (var waited = 0; waited < 300 && !finished; waited += 0.05) pump(0.05)
  if (failure) throw new Error(failure)
  if (!audioFile) throw new Error('no audio was produced')
}

function run(argv) {
  if (argv[0] === 'list') return listing()

  var target = resolve(argv[1], argv[2], argv[3])
  if (!target) return 'FALLBACK'

  var text = decode(argv[6])
  if (!text) return

  var utterance = $.AVSpeechUtterance.speechUtteranceWithString(text)
  utterance.voice = target.voice
  if (argv[4]) utterance.rate = parseFloat(argv[4])

  var output = decode(argv[5])
  if (output) writeToFile(utterance, output)
  else speakAloud(utterance)
}
"""#
}
