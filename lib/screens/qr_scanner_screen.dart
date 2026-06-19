import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../api/api_service.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;
  MobileScannerController cameraController = MobileScannerController();

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() => _isProcessing = true);
    
    try {
      final Map<String, dynamic> qrData = jsonDecode(code);
      if (qrData['type'] == 'ordeno') {
        _showLoteDetails(qrData['id']);
      } else {
        _showError('QR no válido para transporte');
      }
    } catch (e) {
      _showError('Error al leer el QR');
    }
  }

  Future<void> _showLoteDetails(int ordenoId) async {
    try {
      // Buscar el lote asociado al ordeno
      final response = await _apiService.getEntity('lotes');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> lotes = data['response'] ?? data;
        
        final lote = lotes.firstWhere(
          (l) => l['ordenoId'] == ordenoId,
          orElse: () => null,
        );

        if (lote != null) {
          if (!mounted) return;
          _showLoteBottomSheet(lote);
        } else {
          _showError('No se encontró un lote para este ordeño');
        }
      }
    } catch (e) {
      _showError('Error al consultar datos del lote');
    }
  }

  void _showLoteBottomSheet(Map<String, dynamic> lote) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            const Text('🥛', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            const Text(
              'Lote disponible',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildInfoRow('Lote:', 'LT-${lote['fincaNombre'] ?? 'N/A'}-${lote['loteId']}'),
            _buildInfoRow('Finca:', lote['fincaNombre'] ?? 'N/A'),
            _buildInfoRow('Volumen:', '${lote['volumenCapturadoLitros'] ?? 0} L'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showTransportForm(lote);
                },
                icon: const Icon(Icons.directions_car),
                label: const Text('Registrar transporte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3482B9),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ).then((_) => setState(() => _isProcessing = false));
  }

  void _showTransportForm(Map<String, dynamic> lote) {
    final placaController = TextEditingController();
    final tempController = TextEditingController();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registrar transporte',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'LT-${lote['fincaNombre'] ?? 'N/A'}-${lote['loteId']}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _buildTextField('Placa del vehículo', placaController),
              const SizedBox(height: 16),
              _buildTextField('Temperatura inicial (°C) — opcional', tempController, isNumber: true),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (placaController.text.isEmpty) return;
                    
                    setModalState(() => isSaving = true);
                    try {
                      final transportPayload = {
                        "placaVehiculo": placaController.text,
                        "fechaHoraSalida": DateTime.now().toIso8601String(),
                        "fechaHoraEntrada": null, // Se completa al llegar
                        "temperaturaInicio": double.tryParse(tempController.text) ?? 0.0
                      };

                      final res = await _apiService.registerEntity('transportes', transportPayload);
                      
                      if (res.statusCode == 200 || res.statusCode == 201) {
                        final transportData = jsonDecode(res.body);
                        final int transportId = (transportData['response'] ?? transportData)['transporteId'];

                        // Actualizar el lote con el transporteId
                        final updatedLote = Map<String, dynamic>.from(lote);
                        updatedLote['transporteId'] = transportId;
                        
                        await _apiService.updateEntity('lotes', lote['loteId'], updatedLote);

                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transporte guardado con éxito'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    } finally {
                      setModalState(() => isSaving = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA8E6CF), // Light green as in mockup
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Guardar transporte', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4CAF50))),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
    setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 4),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
