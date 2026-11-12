import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    var isActive: Bool
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if isActive && !scanner.isScanning {
            try? scanner.startScanning()
        } else if !isActive && scanner.isScanning {
            scanner.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
            var parent: ScannerView

            init(_ parent: ScannerView) {
                self.parent = parent
            }

            func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
                processItems(addedItems)
            }

            //method to catch updates
            func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {
                processItems(updatedItems)
            }

            private func processItems(_ items: [RecognizedItem]) {
                for item in items {
                    if case .barcode(let barcode) = item,
                       let value = barcode.payloadStringValue {
                        parent.onScan(value)
                        return
                    }
                }
            }
        }
}
