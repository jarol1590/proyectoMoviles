import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';

class LotesScreen extends StatefulWidget {
  const LotesScreen({super.key});

  @override
  State<LotesScreen> createState() => _LotesScreenState();
}

class _LotesScreenState extends State<LotesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _lotes = [];
  bool _isLoading = true;
  int? _fincaId;
  String _fincaNombre = 'Finca';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final userRes = await _apiService.getMe();
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        final user = userData['response'] ?? userData;
        final int usuarioId = user['usuarioId'];

        final producersRes = await _apiService.getEntity('productores');
        if (producersRes.statusCode == 200) {
          final producersData = jsonDecode(producersRes.body);
          final List<dynamic> producers = producersData['response'] ?? producersData;
          final productor = producers.firstWhere((p) => p['usuarioId'] == usuarioId, orElse: () => null);

          if (productor != null) {
            final int productorId = productor['productorId'];

            final fincasRes = await _apiService.getEntity('fincas');
            if (fincasRes.statusCode == 200) {
              final fincasData = jsonDecode(fincasRes.body);
              final List<dynamic> fincas = fincasData['response'] ?? fincasData;
              final finca = fincas.firstWhere((f) => f['productorId'] == productorId, orElse: () => null);

              if (finca != null) {
                setState(() {
                  _fincaId = finca['fincaId'];
                  _fincaNombre = finca['nombre'] ?? 'Finca';
                });
                _loadLotes();
              } else {
                setState(() => _isLoading = false);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error loading initial data for lotes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLotes() async {
    if (_fincaId == null) return;
    try {
      final response = await _apiService.getEntity('lotes/por-finca/$_fincaId');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _lotes = data['response'] ?? data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading lotes: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Mis lotes', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _lotes.isEmpty
                ? const Center(child: Text('No hay lotes registrados'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lotes.length,
                    itemBuilder: (context, index) {
                      final lote = _lotes[index];
                      return _buildLoteCard(lote);
                    },
                  ),
      ),
    );
  }

  Widget _buildLoteCard(Map<String, dynamic> lote) {
    final int id = lote['loteId'];
    final double volumen = (lote['volumenCapturadoLitros'] ?? 0).toDouble();
    final String loteCustomName = 'LOT-$_fincaNombre-$id';
    
    // Logic for states:
    // "Abierto" -> Blue (transporteId == null)
    // "En tránsito" -> Orange (transporteId != null && fechaEntrada == null)
    // "Entregado" -> Green (fechaEntrada != null)
    
    String status = "Abierto";
    Color statusColor = Colors.blueAccent.withOpacity(0.7);
    
    if (lote['transporteFechaHoraEntrada'] != null) {
      status = "Entregado";
      statusColor = Colors.green;
    } else if (lote['transporteId'] != null && lote['transporteId'] != 0) {
      status = "En tránsito";
      statusColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loteCustomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 4),
                Text('$volumen L', style: const TextStyle(color: Colors.grey, fontSize: 15)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          if (status == "Abierto") ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.qr_code_2, color: Colors.blueAccent),
              onPressed: () => _showQrDialog(id, loteCustomName),
            ),
          ]
        ],
      ),
    );
  }

  void _showQrDialog(int loteId, String customName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Center(child: Text(customName)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Comparte este QR con el transportador', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(
                data: jsonEncode({"type": "lote", "id": loteId, "name": customName}),
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))
        ],
      ),
    );
  }
}
