import SwiftUI

struct AboutView: View {
    @Environment(ClassifierEngine.self) private var engine

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What Veto does") {
                    Text("Veto detects unsolicited political outreach in text messages. Eligible incoming messages are classified entirely on this device and, if they cross Veto's threshold, are sent to the Junk list by iOS.")
                }
                Section("Privacy") {
                    Label("On-device classification", systemImage: "iphone")
                    Label("No analytics, no network calls, no message logging", systemImage: "lock.shield")
                }
                Section("Versions") {
                    LabeledContent("Veto iOS", value: appVersion)
                    LabeledContent("Veto Model", value: engine.metadata?.modelVersion ?? "unavailable")
                    LabeledContent("Base Model", value: engine.metadata?.baseModel.split(separator: "/").last.map(String.init) ?? "unavailable")
                    if let threshold = engine.metadata?.threshold {
                        LabeledContent("Threshold", value: threshold.formatted(.number.precision(.fractionLength(4))))
                    }
                }
                Section("Development") {
                    if let load = engine.loadMilliseconds {
                        LabeledContent("Model load", value: String(format: "%.0f ms", load))
                    }
                    if let first = engine.firstInferenceMilliseconds {
                        LabeledContent("First classification", value: String(format: "%.1f ms", first))
                    }
                    Text("Measurements stay on this device.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Enable the filter") {
                    Text("Settings › Messages › Unknown & Spam › Text Message Filter › Veto. Then turn on Filter Unknown Senders if you want filtering applied.")
                        .font(.footnote)
                }
            }
            .navigationTitle("About")
        }
    }
}
