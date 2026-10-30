# Getting started with Xcode

A step-by-step setup for building Veto and running it on your own iPhone. It assumes you already
have a Veto export from the `veto` repository (see the README's *Import the model* section). For the
filter-specific steps after installation, continue with [device-testing.md](device-testing.md).

All commands are run from the root of this repository (the folder containing `project.yml`):

```bash
cd /path/to/veto-ios
```

## 1. Requirements

- A Mac with a recent Xcode (developed with Xcode 26). Install it from the App Store, open it once, and accept the license.
- An iPhone running iOS 17 or later, and a cable.
- An Apple ID. A free one works; a paid Apple Developer Program membership is optional (see *Free vs. paid accounts*).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.

## 2. Import the model

The trained model comes from your own private data and is never committed to this repository.

```bash
scripts/import-veto-model.sh /path/to/veto/dist/coreml
```

This validates the export, copies it into `ModelArtifacts/` (gitignored), prints the model version and
threshold, and runs `xcodegen generate` to create `Veto.xcodeproj`.

The `.xcodeproj` is generated and not committed. Re-run `xcodegen generate` whenever you change
`project.yml` or add or remove source files.

## 3. Add your Apple ID to Xcode

1. Open Xcode, then **Xcode › Settings › Accounts**.
2. Click **+**, choose **Apple ID**, and sign in.
3. You should now see a **Personal Team** entry for your account.

Xcode's Accounts screen does not display the Team ID. Step 5 shows how to find it.

## 4. Choose your bundle ID prefix

iOS requires every app's bundle identifier to be globally unique, so you need a prefix of your own,
usually reverse-DNS style (for example `com.yourname`). Veto derives two identifiers from it:

- `<prefix>.veto` (the app)
- `<prefix>.veto.message-filter` (the Message Filter extension)

Create your local configuration file from the example (it is gitignored):

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Edit `Config/Local.xcconfig`:

```
VETO_BUNDLE_ID_PREFIX = com.yourname
DEVELOPMENT_TEAM =
```

Leave `DEVELOPMENT_TEAM` empty for now. Do not edit `Config/Base.xcconfig`: it holds shared defaults, and
`Local.xcconfig` is loaded after it, so your values take precedence.

Regenerate and open the project:

```bash
xcodegen generate
open Veto.xcodeproj
```

## 5. Select your team and find your Team ID

1. In Xcode, click the blue **Veto** project at the top of the left sidebar.
2. For each of the three targets (**Veto**, **VetoMessageFilter**, **VetoCore**), open **Signing & Capabilities**, keep
   **Automatically manage signing** on, and choose your **Personal Team** under *Team*.
3. Building once makes Xcode create a development certificate. You can then read your Team ID (the
   `OU` field of that certificate) from Terminal:

   ```bash
   security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject
   ```

   The output contains `OU=XXXXXXXXXX`; that 10-character value is your Team ID. (The identifier in
   parentheses after your name in the certificate name is a different ID. Do not use it.)
4. Put the Team ID in `Config/Local.xcconfig`:

   ```
   DEVELOPMENT_TEAM = XXXXXXXXXX
   ```

5. Run `xcodegen generate` again. A team chosen only in Xcode's UI is lost whenever the project is
   regenerated; the value in `Local.xcconfig` is permanent.

## 6. Prepare your iPhone

1. Connect the iPhone and unlock it. Tap **Trust This Computer** and enter your passcode.
2. Enable **Settings › Privacy & Security › Developer Mode**. The phone restarts; confirm the prompt afterward.
   If the option is missing, it appears only after Xcode has connected to the phone once, so try step 7 first.
3. Keep the phone unlocked while installing.

## 7. Build and run on the device

1. In Xcode's top bar, choose the **Veto** scheme and your iPhone as the destination (not a simulator).
2. Press **Run (⌘R)**. The first build takes a few minutes because it compiles the Core ML model.
3. If the phone reports an untrusted developer, go to **Settings › General › VPN & Device Management**,
   tap your Apple ID, and tap **Trust**.

Optional command-line check that signing works (find your device's identifier with
`xcodebuild -scheme Veto -showdestinations`):

```bash
xcodebuild -project Veto.xcodeproj -scheme Veto \
  -destination 'id=<device-id>' -allowProvisioningUpdates build
```

## 8. Verify and continue

Open the app's **Test** tab, tap **Insert sample**, then **Classify**. Check the **About** tab for the
model version, threshold and load time. Then follow [device-testing.md](device-testing.md) to enable the
Message Filter and send test messages.

## Free vs. paid accounts

| | Free Apple ID | Apple Developer Program |
|---|---|---|
| Install on your own device | Yes | Yes |
| Signing validity | About 7 days; rebuild and Run again to renew | About 1 year |
| Distribution to others (TestFlight, App Store) | No | Yes |

When a free signing profile expires, the app stops launching. Reconnect the phone and press Run again;
your app data and the selected Message Filter are normally preserved.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `cp: Config/Local.xcconfig.example: No such file or directory` | You are not in the repository root. `cd` into it first. |
| "Signing for X requires a development team" | Select a team for all three targets and set `DEVELOPMENT_TEAM` (step 5). |
| "Failed to register bundle identifier" | The prefix is already taken by someone else. Choose a different `VETO_BUNDLE_ID_PREFIX` and regenerate. |
| Device missing from the destination list | Unlock and re-plug the phone, confirm trust, and confirm Developer Mode is on. |
| `xcodebuild: Unable to find a device matching the provided destination` | Use the identifier shown by `xcodebuild -showdestinations`, which can differ from the one `devicectl` prints. |
| Phone's iOS version is newer than Xcode supports | Update Xcode, or look for a message naming the required version. |
| App says the model is unavailable | The model was not imported before building. Run the import script (step 2) and rebuild. |
| Changes to `project.yml` have no effect | Run `xcodegen generate`. |
