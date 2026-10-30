# Physical iPhone testing

1. **Signing:** `cp Config/Local.xcconfig.example Config/Local.xcconfig`; set `VETO_BUNDLE_ID_PREFIX` (your reverse-DNS
   prefix) and `DEVELOPMENT_TEAM`. Run `xcodegen generate`. Bundle IDs become `<prefix>.veto` and `<prefix>.veto.message-filter`.
   Or select your team under Signing & Capabilities for the `Veto`, `VetoMessageFilter` and `VetoCore` targets.
2. **Device:** connect the iPhone, tap *Trust*, enable **Settings › Privacy & Security › Developer Mode** (restart), pick the device in Xcode, Run.
3. **Enable the filter:** Settings › Messages › Unknown & Spam › Text Message Filter › **Veto**. Turn on *Filter Unknown Senders*.
   (Paths per recent iOS; verify on your version.)
4. **Send controlled tests** from a number not in your contacts (iOS only filters unknown senders): use the synthetic matrix below.
   Positives should land in *Unknown & Spam › Junk*; negatives in the normal list.
5. **Measure** (not yet done): Instruments (Time Profiler, Allocations) attached to the `VetoMessageFilter` process, model load and
   first-inference time from the About tab (app only), and watch for extension termination (jetsam) in Console.
   If load time or memory is unsafe, stop and take it to Veto's export (quantization / smaller encoder), not here.

## Synthetic matrix
Positive: campaign ad ("Dana Whitfield for Governor … early voting starts Oct. 19"), donation request, GOTV, candidate update,
advocacy group, ballot proposition, election reminder, petition. Negative: personal chat, personal political chat, delivery notice,
auth code, appointment reminder, commercial ad, ordinary spam, transactional. Veto's `parity_fixtures.json` has 70 invented examples
across these categories.
