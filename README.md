# siri-say

`say`, in a Siri voice.

macOS ships two speech engines. `say` uses the older one, which has never
contained the Siri voices. The newer engine does have them, but only shows them to processes
Apple signed.

So `siri-say` parses the command line and it wraps `osascript` for the speaking. The JXA
program it runs is embedded in the binary; there is nothing else to install.

## Installing it

```sh
brew install alongside-software/tap/siri-say

# To use "say" with the new voices
siri-say install
say "Hello World"

# or just use our binary
siri-say "Hello World"
```


Or download the tarball from the releases page, unpack it, and run
`./siri-say install`. The released binary is universal.

`siri-say install` puts a `say` shim beside the binary. If siri-say is already
somewhere that beats `/usr/bin` on PATH — anywhere Homebrew put it — it stays
there and only the shim is added; otherwise it copies itself to
`/usr/local/bin`, or `~/.local/bin` if that is not writable. Choose somewhere
else with `--dir ~/bin`, and undo the lot with `siri-say uninstall`.

`/usr/bin/say` itself is protected by SIP and cannot be replaced, so the shim
wins only because it sits earlier on PATH.
Anything calling `/usr/bin/say` by absolute path is untouched.

## Build and release

```sh
./build.sh                 # -> bin/siri-say, for trying it out
scripts/release.sh         # universal, signed, notarized -> dist/*.tar.gz
```

Building needs the Swift toolchain; running does not. `scripts/release.sh`
signs with `SIRI_SAY_IDENTITY` and notarizes with the notarytool keychain
profile in `SIRI_SAY_NOTARY_PROFILE`, then prints the `url` and `sha256` lines
for `homebrew/siri-say.rb`. A bare executable cannot be stapled, so the ticket
stays on Apple's servers and a downloaded copy needs one network round trip the
first time it runs.

## Use

```sh
siri-say "Migration applied."          # the Siri voice from System Settings
siri-say -v Aaron "Tests passing now."
siri-say -v '?'                        # Siri voices, then say's own list
siri-say -r 220 "A little quicker."
siri-say -o note.aiff "Written, not spoken."
echo "Piped in." | siri-say
```

With no `-v`, it reads the voice Siri is set to — the `Output Voice` entry in
the `com.apple.assistant.backedup` preference domain — and uses the matching
`com.apple.siri.natural.*` voice.

### Voices

Siri voices are named by their identifier's last word: `Aaron`, `Gordon`,
`Aidan`, and so on, one per language and Siri "Voice 1–4" slot. Only the ones
downloaded on this Mac are available; `siri-say voices` lists them. The voice
Siri itself speaks in on a given Mac may be a `custom.siri.*.premium` asset,
which Apple exposes to no third-party process at all — siri-say then falls back
to the same-named natural voice.

### Flags

`-v`, `-r`, `-o`, `-f`, `--`, and text on the command line or standard input
behave as they do in `say`. `-r` is words per minute, mapped onto
AVSpeechUtterance's own 0–1 scale by treating 175 wpm as its midpoint, so it is
close rather than exact. `-o` writes 32-bit float audio in the container the
extension asks for, where `say` writes 16-bit.

Ask for a classic voice (`-v Alex`), or use a flag not in that list
(`--progress`, `-i`, the audio format flags), and siri-say hands the whole
command line to `/usr/bin/say` unchanged.
