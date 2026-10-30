# Distribution

## Current status: build it yourself

Veto is not available on the App Store or TestFlight. It began as a personal project, developed and tested on the
author's own iPhone, and the only supported way to install it is to build it from source with Xcode onto your own
device.

There is no pre-built download, and one is not possible right now:

- Distributing an iOS app to other people requires a paid Apple Developer Program membership, which this project
  does not have.
- The classifier is trained on the author's private messages, and that model is deliberately not published (see the
  README's privacy section). A shared binary would have to include somebody's model, so you bring your own.

## How to set it up for yourself

Everything you need is in this repository:

1. **Train and export a model** with the separate `veto` repository (the Python/ML pipeline that
   produces the Core ML export this app consumes). You need your own labeled messages.
2. **Follow [getting-started-xcode.md](getting-started-xcode.md)**: import your export, set your Apple ID, bundle ID
   prefix and Team ID, and install on your iPhone.
3. **Follow [device-testing.md](device-testing.md)** to enable the Message Filter and verify it with test messages.

A free Apple ID is enough. The trade-offs of building with a free account:

- The install expires after about 7 days. Reconnect the phone and press Run in Xcode to renew it.
- You rebuild whenever you want to update the app.
- Each phone needs to be set up from a Mac running Xcode.

## Possible future: wider distribution

If the project gains enough traction, the plan is to join the Apple Developer Program and offer easier installs. The
likely route is TestFlight for testers, and possibly the App Store later. Open questions before that can happen:

- **Model:** what model ships to users (a model trained on shareable data, or an on-device training or import flow)
  and what threshold suits a broader audience than one person's messages.
- **Review requirements:** a privacy policy and description of the Message Filter extension, plus an original icon
  and name that do not imitate Apple's Messages branding.
- **Device measurements:** extension load time, memory and latency on a range of iPhones, using a Release build.

None of this is committed or scheduled. For now, build from source.
