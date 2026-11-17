import SwiftUI
import VisionKit

struct ScanView: View {
    @State private var scannedCode = ""
    @State private var outcome: ScanOutcome = .loading
    @State private var showResult = false
    @State private var isScanning = true // Control scanning state explicitly

    var body: some View {
        VStack(spacing: 16) {
            Text("GlutenScan")
                .font(.largeTitle)
                .bold()

            if DataScannerViewController.isSupported &&
               DataScannerViewController.isAvailable {
                ScannerView(isActive: isScanning) { code in
                    handleScan(code)
                }
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)

                Text("Point the camera at a barcode")
                    .foregroundStyle(.secondary)
            } else {
                Text("Scanner not available. Run on a real iPhone and allow camera access.")
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
        .sheet(isPresented: $showResult, onDismiss: resumeScanning) {
            ScanResultView(barcode: scannedCode, outcome: outcome) {
                showResult = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleScan(_ code: String) {
        // The scanner can report the same code a few times before it stops.
        guard !showResult else { return }

        isScanning = false // Pause immediately on scan
        scannedCode = code
        outcome = .loading
        showResult = true

        Task {
            let result = await ScanOutcome.check(barcode: code)
            // Ignore a late answer if the popup was closed or a new code scanned.
            if showResult && scannedCode == code {
                outcome = result
            }
        }
    }

    private func resumeScanning() {
        // Add a 1-second cooldown before restarting the camera feed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isScanning = true
        }
    }
}

#Preview {
    ScanView()
}
