import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var hasCompleted = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedContent()
    }

    private func processSharedContent() {
        guard !hasCompleted,
              let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            complete()
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] value, _ in
                let text: String?
                if let url = value as? URL {
                    text = url.absoluteString
                } else if let string = value as? String {
                    text = string
                } else {
                    text = nil
                }
                DispatchQueue.main.async { self?.openRideDash(with: text) }
            }
            return
        }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] value, _ in
                DispatchQueue.main.async {
                    self?.openRideDash(with: value as? String)
                }
            }
            return
        }

        complete()
    }

    private func openRideDash(with sharedValue: String?) {
        guard let sharedValue,
              !sharedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var components = URLComponents(string: "ridedash://route") else {
            complete()
            return
        }

        components.queryItems = [URLQueryItem(name: "url", value: sharedValue)]
        guard let url = components.url else {
            complete()
            return
        }

        extensionContext?.open(url) { [weak self] _ in
            self?.complete()
        }
    }

    private func complete() {
        guard !hasCompleted else { return }
        hasCompleted = true
        extensionContext?.completeRequest(returningItems: nil)
    }
}
