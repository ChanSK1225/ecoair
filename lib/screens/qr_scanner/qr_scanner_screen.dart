import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  bool _handledScan = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QR Scanner',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Scan indoor air quality devices',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle flashlight',
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flash_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) => _buildCameraError(error),
            placeholderBuilder: (context) => Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
          _buildScannerOverlay(),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Align the device QR code inside the frame.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _showScanResult('EA-IND-KL-042'),
                  icon: const Icon(Icons.memory_outlined),
                  label: const Text('Use Demo Device'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F9D58),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_handledScan) return;

    String? rawValue;
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.trim().isNotEmpty) {
        rawValue = barcode.rawValue!.trim();
        break;
      }
    }

    if (rawValue == null) return;
    _handledScan = true;
    unawaited(_controller.stop());
    _showScanResult(rawValue);
  }

  Future<void> _showScanResult(String scannedValue) async {
    final messenger = ScaffoldMessenger.of(context);
    final deviceId = scannedValue.startsWith('EA-')
        ? scannedValue
        : 'EA-IND-KL-042';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Device Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device ID: $deviceId',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (!scannedValue.startsWith('EA-'))
              Text(
                'QR value: $scannedValue',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            const Text('CO2: 450 ppm'),
            const Text('PM2.5: 12 ug/m3'),
            const Text('Temperature: 24.5\u00B0C'),
            const Text('Humidity: 45%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              messenger.showSnackBar(
                SnackBar(content: Text('Device $deviceId added to dashboard.')),
              );
            },
            child: const Text('Add to Dashboard'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    setState(() => _handledScan = false);
    unawaited(_controller.start());
  }

  Widget _buildScannerOverlay() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: Container(
          width: 260,
          height: 260,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF86EFAC), width: 3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Icon(Icons.qr_code_2, size: 88, color: Color(0x6686EFAC)),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraError(MobileScannerException error) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.no_photography_outlined,
            color: Colors.white,
            size: 56,
          ),
          const SizedBox(height: 16),
          const Text(
            'Camera is unavailable',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.errorDetails?.message ??
                'Please allow camera permission or use the demo device button.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
