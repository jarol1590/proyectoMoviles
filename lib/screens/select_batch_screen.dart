import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';
import 'samples_screen.dart';

class SelectBatchScreen extends StatefulWidget {
  final int centroAcopioId;

  const SelectBatchScreen({super.key, required this.centroAcopioId});

  @override
  State<SelectBatchScreen> createState() => _SelectBatchScreenState();
}

class _SelectBatchScreenState extends State<SelectBatchScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _lotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLotes();
  }

  Future<void> _fetchLotes() async {
    setState(() => _isLoading = true);
    try {
      // Intentamos obtener lotes por centro de acopio
      // Si el endpoint no existe, intentamos filtrar todos los lotes
      final response = await _apiService.getEntity('lotes');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allLotes = data['response'] ?? data;
        
        setState(() {
          // Filtramos los que pertenecen a este centro de acopio
          final List<dynamic> filtered = allLotes.where((l) => l['centroAcopioId'] == widget.centroAcopioId).toList();
          
          // Ordenamos por loteId de mayor a menor para que el más nuevo aparezca arriba
          filtered.sort((a, b) => (b['loteId'] ?? 0).compareTo(a['loteId'] ?? 0));
          
          _lotes = filtered;
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar lotes');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar lotes: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar lote'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _lotes.isEmpty
              ? const Center(child: Text('No hay lotes en este centro de acopio'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _lotes.length,
                  itemBuilder: (context, index) {
                    final lote = _lotes[index];
                    final String fincaNombre = lote['fincaNombre'] ?? 'Finca';
                    final String loteName = 'LT-$fincaNombre-${lote['loteId']}';
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.business, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(fincaNombre, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 20),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            title: Text(loteName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Text('Volumen: ${lote['volumenCapturadoLitros'] ?? 0} L'),
                            onTap: () {
                              // Intentamos obtener el fincaId de varias posibles ubicaciones en el objeto lote
                              final int fincaId = lote['fincaId'] ?? 
                                                 lote['finca_id'] ??
                                                 lote['idFinca'] ??
                                                 lote['ordeno']?['fincaId'] ?? 
                                                 lote['finca']?['fincaId'] ?? 
                                                 0;
                              
                              print('DEBUG: Lote seleccionado: $lote');
                              print('DEBUG: fincaId detectado: $fincaId');
                              
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SamplesScreen(
                                    lote: lote,
                                    centroAcopioId: widget.centroAcopioId,
                                    fincaId: fincaId,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
