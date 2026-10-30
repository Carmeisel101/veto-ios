# Latency report

Measured 2026-10-30 with Veto model v1 (MiniLM encoder + logistic regression, FP16 Core ML, input length fixed at
256 tokens). Xcode 26.3, simulator runtime iOS 26.3.

**Bottom line:** the only real-device numbers so far come from one iPhone 14, in the app, from a single Debug-build
run. Nothing has been measured **inside the Message Filter Extension**, which is the number that decides whether the
filter is viable. Simulator numbers below describe the development Mac, not any iPhone.

## 1. Real device: iPhone 14, in the app

Read from the app's Test and About screens on one iPhone 14 (iOS 27.0.1), Debug build run from Xcode, one
classification after a cold launch.

| Metric | Value |
|---|---|
| Model load | 1,512 ms |
| Tokenize | 3.98 ms |
| Inference (first call) | 793 ms |
| First classification, total | 797 ms |

How to read this:
- The first call includes one-time Core ML setup, so it overstates what a typical message costs. Warm latency on the
  phone has **not** been measured.
- Debug builds are unoptimized, which likely inflates the tokenizer time (the Python tokenizer takes about 0.15 ms).
  The Release-build simulator run in section 3 suggests build configuration barely affects inference.
- This is app-process timing. iOS may give an extension different resources and stricter limits.

## 2. Reference: Veto's Mac benchmark (Python side)

From the export's own benchmark (Apple M2 Pro, macOS 15.6.1, 200 runs after 20 warm-up runs, medians):

| Stage | Compute units | Median | p95 |
|---|---|---|---|
| Tokenization | n/a | 0.147 ms | 0.191 ms |
| Core ML inference | All (CPU/GPU/Neural Engine) | 2.24 ms | 2.56 ms |
| Core ML inference | CPU only | 5.61 ms | 6.32 ms |
| Tokenize + inference | All | 2.43 ms | 2.82 ms |
| Tokenize + inference | CPU only | 5.81 ms | 6.57 ms |

This shows what the model can do with hardware acceleration on a fast Mac. It says nothing about an iPhone.

## 3. iOS Simulator (development Mac)

Warm latency of the same classification path (30 runs after one warm-up; median and 95th percentile), from
`ModelParityTests.testWarmInferenceLatencyIsReported`. Core ML parity with Python was checked in the same runs.

| Simulated device | Configuration | Warm median | p95 | Python parity (70 fixtures) |
|---|---|---|---|---|
| iPhone 14 | Debug | 48.2 ms | 55.8 ms | max diff 0.0037, 0 decision disagreements |
| iPhone 17 | Debug | 47.1 ms | 50.5 ms | max diff 0.0037, 0 decision disagreements |
| iPhone 17 Pro | Debug | 47.0 ms | 49.1 ms | max diff 0.0037, 0 decision disagreements |
| iPhone 17 Pro | Release | 45.6 ms | 48.1 ms | max diff 0.0037, 0 decision disagreements |

How to read this:
- **A simulator does not emulate the iPhone's chip.** It runs the model on the Mac, so the differences between rows are
  noise. Use these rows to confirm the model runs and matches Python on each device configuration, not to compare
  phones.
- The ~47 ms is far above the 2–6 ms of section 2, so the simulator evidently does not use the Neural Engine or GPU the
  way a native run does. Treat it as a no-accelerator worst case.
- Debug vs Release differs by about 3%, so inference time is dominated by Core ML, not Swift code.
- iPhone 18 Pro could not be tested: no such simulator exists in Xcode 26.3.

## 4. What is not measured yet

| Missing | Why it matters |
|---|---|
| Warm latency on a real iPhone | The first-call figure is mostly one-time setup. |
| Release build on a real iPhone | Debug builds are not representative. |
| Latency and model load inside the Message Filter Extension | iOS limits extension time and memory. A slow or memory-hungry extension can be killed, and then messages pass through unfiltered. |
| Peak memory in the extension | The model is about 43 MB on disk; the loaded footprint is unknown. |
| Other iPhones | Only an iPhone 14 has been tried. Older devices without a fast Neural Engine may be much slower. |

If extension timing turns out to be too slow or too large, improvements (weight quantization, a smaller encoder) belong
in the `veto` export pipeline, not in this repository.

## 5. Reproduce

Simulator latency (needs your own model imported; see [getting-started-xcode.md](getting-started-xcode.md)):

```bash
xcodegen generate
xcodebuild test -project Veto.xcodeproj -scheme Veto \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VetoTests/ModelParityTests
```

Look for the `VETO_LATENCY` line in the output. For a Release configuration add
`-configuration Release ENABLE_TESTABILITY=YES`.

Real device: run the app from Xcode on your iPhone, classify a message, and read the timings on the Test tab; model load
and first-classification times are on the About tab. Use Instruments (Time Profiler, Allocations) attached to the
`VetoMessageFilter` process for extension measurements ([device-testing.md](device-testing.md)).
