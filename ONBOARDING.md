# Embla 2.0 (Flutter) — orientation

Branch: **`embla-2`**. `master` is the shipped 1.4.0 app and is not touched.

This is the `embla-2.0` pipeline inside the existing Flutter app, so it keeps the
UI, animations, hotword and settings, and runs on both platforms.

## What the pipeline does

```
mic → Hreimur (/long_asr/) → OpenAI gpt-5.6-luna + tools → Icespeak TTS
```

Typed input skips the first stage. Both TTS and LLM are switchable in Settings:
ElevenLabs instead of Icespeak, and Gemini instead of OpenAI — where Gemini is
the **fused path**, taking the recording directly and transcribing plus
answering in one call. On one 2.88 s Icelandic clip that measured 2.03 s against
3.12 s for Hreimur transcribing alone, with an exact transcript. It is not the
default yet.

Differences from the Swift MVP worth knowing before you look for things:

- The tool loop is **multi-turn** (cap 5 iterations), not a single classification.
  Conversation history is kept and tool results are fed back.
- There is **TTS**, and a `speech` / `display` split — `speech` is what gets
  spoken, `display` may carry numbers and links.
- `greynir_query` exists, so it answers questions rather than only classifying.
- Streaming ASR was removed. Ratatoskur's `short_asr` is Azure-backed; 2.0
  standardises on Hreimur. The `AsrEngine` interface and `AsrEvent.isFinal` are
  left intact so streaming slots back in when Hreimur streams.

## Where things live, coming from `embla-2.0`

| There | Here |
|---|---|
| `ActionCatalog` in `Interpreter.swift` | one class per tool in `lib/tools/`, registered in `lib/tools/device_tools.dart` |
| `LocalActions.swift` | `ios/Runner/EmblaActions.swift` — EventKit, AlarmKit, Reminders |
| `Interpreter.swift` (LLM call) | `lib/llm/` — `openai_responses_client.dart`, `gemini_client.dart` |
| `Pipeline.swift` | `lib/assistant/assistant_session.dart` |
| `Intent.swift` | `InterpretCommandIntent` in `ios/Runner/EmblaActions.swift` |
| `Recorder.swift` | `lib/asr/hreimur_batch_asr.dart` (capture, silence detection, upload) |
| prompt | `lib/assistant/prompt.dart` |

Most work is Dart. Swift is only for things that need an iOS API, and the whole
native surface is one file.

Tools present: `greynir_query`, `get_datetime`, `get_location`, `open_url`,
`add_calendar_event`, `add_reminder`, `set_timer`, `set_alarm`, `draft_message`,
`list_alarms`, `cancel_alarms`, `get_directions`, `add_shopping`.
Missing versus your repo: **Spotify**.

## Shortcuts

`InterpretCommandIntent` ("Túlka raddskipun") brings the app forward, runs one
turn and returns the result. The contract is deliberately yours, so shortcuts
written against the Swift app keep working: always a dictionary with `action` of
`done` or `none`, and failures are `none` with a `reason` rather than a thrown
error. Nothing on that path throws.

`openAppWhenRun` is true for the same reason as yours — mic capture cannot start
in the background, which also means the device must be unlocked.

## Getting it running

Known-good: **Flutter 3.47.2**, **Xcode 26**, **CocoaPods 1.17**. A physical
iPhone is required (see gotchas).

```bash
git clone git@github.com:mideind/EmblaFlutterApp.git
cd EmblaFlutterApp
git checkout embla-2
```

`embla_core` and `flutter_snowboy` are git dependencies in `pubspec.yaml`, so
there is nothing to check out alongside the repo.

Create the key files (see `keys/README.md`); missing ones become empty strings
and that feature degrades rather than breaking the build:

```bash
printf '%s' 'YOUR_MIDEIND_KEY' > keys/server.key      # required: ASR + TTS
printf '%s' 'YOUR_OPENAI_KEY' > keys/openai.key       # required: the LLM
printf '%s' 'YOUR_GEMINI_KEY' > keys/gemini.key       # optional: fused audio
printf '%s' 'YOUR_ELEVENLABS_KEY' > keys/elevenlabs.key  # optional: alt TTS
bash keys/gen_keys.sh
flutter pub get
```

Signing: open `ios/Runner.xcworkspace`, set your team and a bundle identifier
you can sign. **Do not commit that** — see gotchas.

```bash
flutter run -d <your-device-id>     # flutter devices to list
flutter analyze && flutter test     # 203 tests, both expected clean
```

## Gotchas that will cost you an hour each

- **`pod install` fails with a Ruby `ASCII-8BIT` error** unless the terminal is
  UTF-8. CocoaPods warns about this itself. `export LANG=en_US.UTF-8`.
- **The simulator does not build.** Snowboy ships no arm64-simulator slice, and
  the failure is at link time so no runtime flag avoids it. Physical device
  only, until Snowboy is replaced.
- **Do not commit these**, they are per-machine and will break everyone else:
  `ios/Runner.xcodeproj/project.pbxproj` (signing),
  `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`,
  `ios/Runner/Info.plist` when the only change is Xcode re-sorting keys, and
  `ios/Flutter/AppFrameworkInfo.plist`, which Flutter rewrites on every build.
  Those four will sit permanently modified in `git status`; that is expected.
- **`use_modular_headers!` in the Podfile is load-bearing**, for two unrelated
  pods — `flutter_sound_core` needs a module map, and `permission_handler_apple`
  9.1.4 has a header clang rejects otherwise. Narrowing it to one pod breaks the
  build. The comment there explains when it can go.
- **`wakelock_plus` is pinned with a `dependency_overrides` entry.** Its 1.1.x
  native code registers pre-prefix pigeon channels that only platform_interface
  1.1.0 calls; anything newer resolves to prefixed names and every wakelock call
  throws at runtime. Do not "tidy" that pin.
- **Android has never been built on this branch.** The code paths exist
  (AlarmClock intents, calendar fallback for reminders, `READ_CONTACTS`) and are
  unit-tested, but nothing has compiled. Treat first Android build as real work.
- **`/rat/v2/tts` only accepts ASCII voice names.** `Guðrún` returns an instant
  504 from the origin. `lib/util.dart` transliterates at the wire boundary;
  prefs and the bundled audio assets keep the Icelandic spelling.

## Open questions worth your opinion

- **Silence detection** is 800 ms here versus 1.5 s in your `Recorder.swift`.
  Ours may clip someone who pauses mid-sentence; yours is presumably tuned for
  car noise. Nobody has compared them on the same audio.
- **`reasoning: 'none'`** was adopted from your repo. Our tool loop asks more of
  the model than your single classification, so relative dates ("eftir hálftíma")
  are the thing to watch.
- **Icelandic name declension.** `draft_message` resolves "Kára Steini" to the
  contact "Kári Steinn" by stem matching, which cannot handle stem-vowel changes
  (Anna → Önnu). The real fix is BÍN. See the plan file for the findings.
