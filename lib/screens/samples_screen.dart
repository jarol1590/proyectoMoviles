import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import 'new_analysis_screen.dart';

class SamplesScreen extends StatefulWidget {
  final Map<String, dynamic> lote;
  final int centroAcopioId;
  final int fincaId;

  const SamplesScreen({
    super.key,
    required this.lote,
    required this.centroAcopioId,
    required this.fincaId,
  });

  @override
  State<SamplesScreen> createState() => _SamplesScreenState();
}

class _SamplesScreenState extends State<SamplesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _samples = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Obtener el ID del usuario actual para registrar muestras
      final meRes = await _apiService.getMe();
      if (meRes.statusCode == 200) {
        final meData = jsonDecode(meRes.body);
        _userId = (meData['response'] ?? meData)['usuarioId'];
      }

      final response = await _apiService.getEntity('muestras/por-lote/${widget.lote['loteId']}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _samples = data['response'] ?? data;
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar muestras');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createNewSample() async {
    if (_userId == null) return;
    
    try {
      final response = await _apiService.registerEntity('muestras', {
        'loteId': widget.lote['loteId'],
        'tecnicoPorUsuarioId': _userId,
        'fechaHoraToma': DateTime.now().toIso8601String(),
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        _loadData(); // Recargar lista
      } else {
        throw Exception('No se pudo crear la muestra');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear muestra: $e')),
        );
      }
    }
  }

  Future<void> _deleteSample(Map<String, dynamic> sample) async {
    final int muestraId = sample['muestraId'];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar muestra'),
        content: const Text('¿Estás seguro? Se eliminará la muestra, el análisis y todos sus resultados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        // 1. Buscar el análisis asociado
        final analysisRes = await _apiService.getEntity('analisis-calidad/por-finca/${widget.fincaId}');
        if (analysisRes.statusCode == 200) {
          final data = jsonDecode(analysisRes.body);
          final List<dynamic> analyses = data['response'] ?? (data is List ? data : []);

          final analysis = analyses.firstWhere(
            (a) => a['muestraId'] == muestraId || a['loteId'] == widget.lote['loteId'],
            orElse: () => null
          );

          if (analysis != null) {
            final int analysisId = analysis['analisisId'];
            print('DEBUG: Borrando resultados para Analisis ID: $analysisId');

            // 2. Borrar resultados de parámetros uno por uno
            final paramsRes = await _apiService.getEntity('parametros-calidad/centro/${widget.centroAcopioId}');
            if (paramsRes.statusCode == 200) {
              final paramsData = jsonDecode(paramsRes.body);
              final List<dynamic> parameters = paramsData['response'] ?? paramsData;

              for (var p in parameters) {
                final int paramId = p['parametroId'];
                // DELETE /api/resultados-parametro/{analisisId}/{parametroId}
                await _apiService.deleteEntity('resultados-parametro/$analysisId', paramId);
              }
            }

            // 3. Borrar el análisis
            print('DEBUG: Borrando análisis principal...');
            await _apiService.deleteEntity('analisis-calidad', analysisId);
          }
        }

        // 4. Borrar la muestra
        print('DEBUG: Borrando muestra final...');
        final response = await _apiService.deleteEntity('muestras', muestraId);

        if (response.statusCode == 200 || response.statusCode == 204) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eliminado con éxito'), backgroundColor: Colors.green));
            _loadData();
          }
        } else {
          throw Exception('Error al borrar muestra: ${response.statusCode}');
        }
      } catch (e) {
        print('DEBUG: Error en borrado: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muestras'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _createNewSample,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Nueva muestra'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Analizadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _samples.isEmpty
                        ? const Center(child: Text('No hay muestras registradas'))
                        : ListView.builder(
                            itemCount: _samples.length,
                            itemBuilder: (context, index) {
                              final sample = _samples[index];
                              final bool analyzed = sample['tieneAnalisis'] ?? false;
                              final date = DateTime.parse(sample['fechaHoraToma']).toLocal();
                              
                              return Card(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text('Muestra #${sample['muestraId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${date.day}/${date.month}/${date.year}, ${date.hour}:${date.minute}:${date.second}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: analyzed ? Colors.green : Colors.orange[100],
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          analyzed ? 'Analizada' : 'Pendiente',
                                          style: TextStyle(
                                            color: analyzed ? Colors.white : Colors.orange[800],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    /*  IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _deleteSample(sample),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),*/
                                    ],
                                  ),
                                  onTap: analyzed ? null : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => NewAnalysisScreen(
                                          sample: sample,
                                          loteName: 'LT-${widget.lote['fincaNombre']}-${widget.lote['loteId']}',
                                          centroAcopioId: widget.centroAcopioId,
                                        ),
                                      ),
                                    ).then((value) {
                                      if (value == true) _loadData();
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
