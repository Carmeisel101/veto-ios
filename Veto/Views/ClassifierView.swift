import SwiftUI
import VetoCore

struct ClassifierView: View {
    @Environment(ClassifierEngine.self) private var engine
    @State private var text = ""
    @FocusState private var focused: Bool

    private static let samples = [
        "Dana Whitfield for Governor: safer neighborhoods, better schools. Early voting starts Oct. 19. Reply STOP to end",
        "Your verification code is 482913. Do not share it with anyone.",
        "Hey, are we still on for dinner at 7? I'll grab the table.",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("Classification happens on this device. Message contents are not sent to a server by Veto.",
                          systemImage: "lock.shield")
                        .font(.footnote)
                }
                switch engine.state {
                case .failed(let message):
                    Section("Model unavailable") { Text(message).font(.footnote) }
                case .idle, .loading:
                    Section { ProgressView("Loading model…") }
                case .ready:
                    inputSection
                    resultSection
                }
            }
            .navigationTitle("Veto")
        }
    }

    private var inputSection: some View {
        Section("Message") {
            TextField("Paste or type a message", text: $text, axis: .vertical)
                .lineLimit(3...8)
                .focused($focused)
            Menu("Insert sample") {
                ForEach(Self.samples, id: \.self) { sample in
                    Button(sample.prefix(48) + "…") { text = sample }
                }
            }
            Button("Classify") {
                focused = false
                Task { await engine.classify(text) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.isEmpty)
        }
    }

    @ViewBuilder private var resultSection: some View {
        if let message = engine.errorMessage {
            Section("Error") { Text(message).font(.footnote) }
        }
        if let prediction = engine.lastPrediction {
            Section("Result") {
                Label(prediction.isPoliticalSolicitation ? "Political Solicitation" : "Not Political Solicitation",
                      systemImage: prediction.isPoliticalSolicitation ? "exclamationmark.bubble.fill" : "checkmark.bubble")
                    .font(.headline)
                    .foregroundStyle(prediction.isPoliticalSolicitation ? .red : .green)
                LabeledContent("Probability", value: prediction.probability.formatted(.percent.precision(.fractionLength(1))))
                LabeledContent("Threshold", value: prediction.threshold.formatted(.percent.precision(.fractionLength(1))))
                if let timings = engine.lastTimings {
                    LabeledContent("Tokenize", value: String(format: "%.2f ms", timings.tokenizeMilliseconds))
                    LabeledContent("Inference", value: String(format: "%.2f ms", timings.inferenceMilliseconds))
                }
            }
        }
    }
}
