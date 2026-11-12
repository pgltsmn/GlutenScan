import SwiftUI
import VisionKit

struct ScanView: View {
    @State private var scannedCode = ""
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
                    scannedCode = code
                    showResult = true
                    isScanning = false // Pause immediately on scan
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
        .alert("Scanned!", isPresented: $showResult) {
            Button("OK") {
                scannedCode = ""
                showResult = false
                
                // Add a 1-second cooldown before restarting the camera feed
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isScanning = true
                }
            }
        } message: {
            Text("Barcode: \(scannedCode)")
        }
    }
}

#Preview {
    ScanView()
}
