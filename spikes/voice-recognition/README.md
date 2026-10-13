---
id: "SPIKE-VOICE-001"
type: "spec"
title: "On-device recognition comparison harness"
status: "draft"
updated: "2026-10-10"
owner: "assistant"
tags: ["area/macos", "area/quality", "phase/r1"]
summary: "Reproducible TASK-093 names-only comparison and explicit missing human evidence."
related: ["PLAN-004", "DOC-VALIDATION", "DOC-TASKS"]
---

# TASK-093: on-device recognizer spike

The comparison harness is implemented; the recognition experiment is **not complete**.
No real names, recordings, recognition accuracy, live listening latency, CPU/energy
measurements, or permission-prompt observations have been supplied. Always-on wake
recognition is **no-go pending evidence**, rather than demonstrated unsuitable.
TASK-095 must not describe a recognizer choice as empirically selected yet.

## Verified machine capability

Read-only probes outside the execution sandbox on 2026-10-10: Apple silicon,
macOS 26.6.2 (25G83), Swift 6.4, Xcode macOS 27 SDK, deployment target macOS 26.

| Capability | en-GB | en-US |
| --- | --- | --- |
| `SFSpeechRecognizer.isAvailable` | true | true |
| `supportsOnDeviceRecognition` | false | true |
| `SpeechTranscriber.isAvailable` | true | true |
| Equivalent supported locale | en_GB | en_US |
| Analyzer assets | supported, not installed | supported, not installed |

Speech Recognition authorization was not determined (raw value 0); Microphone was
authorized (raw value 3). The probe requested neither. Sandbox probes gave different
permission and locale results; they cannot establish the machine's capabilities.
The legacy en-GB path refuses recognition, rather than using network recognition.

Signatures were checked in the local Speech SDK `.swiftinterface` and headers,
then compiled: `SpeechTranscriber(locale:preset:)`,
`SpeechAnalyzer.start(inputAudioFile:finishAfterFile:)`, `AssetInventory.status`,
`assetInstallationRequest(supporting:)`, `SFSpeechURLRecognitionRequest(url:)`,
`requiresOnDeviceRecognition`, and `recognitionTask(with:resultHandler:)`.
No third-party package or runtime dependency is added.

## Run the actual comparison

```sh
swift test --package-path spikes/voice-recognition
bash spikes/voice-recognition/Scripts/build-app.sh
# Use the printed app path below. This opens buttons; it does not prompt on launch.
open /printed/path/VoiceSpike.app --args permissions
```

The bundle has separate Speech Recognition and Microphone buttons, plus explicit
asset-install buttons for the two comparison locales. Only clicking an install
button downloads Apple's model assets. No microphone capture exists in this spike.
Granting its microphone permission is an observation of the bundled permission
flow, not proof that Porter listening works. This separate ad-hoc-signed spike
does not establish permission identity or behavior for the Porter application.

Keep input outside the repository: at least 30 **real** distinct project/chat
names, using opaque ids and one names-only recording per name, without message
text. Have the person say each name in their usual voice; synthesized names are
not real-voice accuracy evidence. Use at least two genuinely different groups
(short project names and multiword chat titles, including actual uncommon names).
Record language/accent, audio conditions, repetitions, and which names belong to
which group privately. Do not paste those names or recordings into project memory.

The private JSON manifest has records with `id`, `expected`, and `audio` fields;
`audio` is an absolute path or relative to the manifest. Example shape only:

```json
[{"id":"01","expected":"<real project or chat title>","audio":"01.wav"}]
```

That single-record example is deliberately rejected: the harness requires 30
distinct names. Both recognizers process the same input files. The analyzer
requires installed local assets; the legacy API requires authorization and
`supportsOnDeviceRecognition`, with `requiresOnDeviceRecognition = true`.
There is no fallback or automatic asset download during recognition.

```sh
APP=/printed/path/VoiceSpike.app/Contents/MacOS/VoiceSpike
"$APP" capabilities en-GB
"$APP" capabilities en-US
bash spikes/voice-recognition/Scripts/measure.sh "$APP" analyzer /private/corpus.json en-US
bash spikes/voice-recognition/Scripts/measure.sh "$APP" legacy /private/corpus.json en-US
```

Use the **same bundled executable** after authorizing it. JSON lines contain only
opaque id, engine, match boolean, wall seconds, and client CPU seconds. Expected
and recognized names are compared in memory and never written by the harness.
The input files remain under the user's control. Use opaque ids: ids are output.
Compare aggregate and per-group exact-name accuracy; punctuation/case/whitespace
are ignored while accents, digits, word order, and near misses remain distinct.
No close-match navigation decision is inferred from this accuracy metric.

Run both orders, repeat on the same recordings, and distinguish first-run from
warmed trials. Wall time covers complete file recognition, not post-utterance
or live microphone latency. Client CPU and `/usr/bin/time` exclude Apple's
recognizer service CPU. `measure.sh` prints battery before/after and bounds the
corpus run to 60 seconds per entry; those battery snapshots are not energy proof.

## Outstanding evidence and gate

The harness is a scripted comparison, replacing a handwritten file-recognition
procedure. It intentionally does not implement the production VoiceListener.
The continuous-listening measurement script and live probe are still required:
measure client **and recognizer service** CPU, device energy on battery, and
false/true wake detections over real speech and silence. Define a budget before
those experiments; none is approved in this spike. File CPU and file accuracy
cannot authorize always-on listening. The SDK working and a model being supported
also cannot demonstrate accuracy on real titles.

No verification available for real-voice accuracy, microphone listening,
permission prompt appearance, battery cost, or wake phrase reliability. Checked
instead: both APIs compile under Swift 6 strict concurrency; corpus validation,
normalization on conventional and accented/digit/non-Latin input groups, metrics
privacy, shell syntax, bundle plist, signature, and read-only locale capabilities.
