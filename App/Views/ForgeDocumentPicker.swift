import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Direct Files picker used for signing inputs. Unlike SwiftUI's fileImporter,
/// this requests a generic item and validates the selected extension in the
/// receiving screen, so Files does not grey out P12, mobileprovision, or IPA.
struct ForgeDocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: ([URL]) -> Void
    let onCancel: () -> Void

    init(onPick: @escaping ([URL]) -> Void,
         onCancel: @escaping () -> Void) {
        self.contentTypes = [.item]
        self.onPick = onPick
        self.onCancel = onCancel
    }

    init(contentTypes: [UTType],
         onPick: @escaping ([URL]) -> Void,
         onCancel: @escaping () -> Void) {
        self.contentTypes = contentTypes
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: contentTypes,
            asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onPick: ([URL]) -> Void
        private let onCancel: () -> Void

        init(onPick: @escaping ([URL]) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
