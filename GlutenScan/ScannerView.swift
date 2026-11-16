import SwiftUI
import VisionKit

/// Hosts a DataScannerViewController and restarts it whenever its view comes
/// back on screen (for example after switching tabs). VisionKit stops scanning
/// when the view disappears, and SwiftUI won't re-run the update method unless
/// `isActive` changes, so appearance is handled here instead.
final class ScannerContainerController: UIViewController {
    let scanner: DataScannerViewController
    var wantsScanning = false

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if scanner.isScanning {
            scanner.stopScanning()
        }
    }

    func startIfNeeded() {
        guard wantsScanning, !scanner.isScanning, viewIfLoaded?.window != nil else { return }
        try? scanner.startScanning()
    }
}

struct ScannerView: UIViewControllerRepresentable {
    var isActive: Bool
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerContainerController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return ScannerContainerController(scanner: scanner)
    }

    func updateUIViewController(_ container: ScannerContainerController, context: Context) {
        context.coordinator.parent = self
        container.wantsScanning = isActive
        if isActive {
            container.startIfNeeded()
        } else if container.scanner.isScanning {
            container.scanner.stopScanning()
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
