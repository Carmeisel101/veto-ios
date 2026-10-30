import IdentityLookup
import VetoCore

/// Classifies messages iOS hands to the filter. Fails open: any problem leaves the message alone.
final class MessageFilterExtension: ILMessageFilterExtension {
    /// Loaded once per extension process. `nil` (load failure) means every message is allowed.
    private static let classifier: VetoClassifier? = try? VetoClassifier.load(computeUnits: .cpuOnly)
}

extension MessageFilterExtension: ILMessageFilterQueryHandling {
    func handle(_ queryRequest: ILMessageFilterQueryRequest,
                context: ILMessageFilterExtensionContext,
                completion: @escaping (ILMessageFilterQueryResponse) -> Void) {
        let response = ILMessageFilterQueryResponse()
        response.action = .none
        if let body = queryRequest.messageBody, !body.isEmpty,
           let classifier = Self.classifier, classifier.shouldFilter(body) {
            response.action = .junk
        }
        completion(response)
    }
}
