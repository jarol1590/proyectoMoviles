import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';

class OrdenosScreen extends StatefulWidget {
  const OrdenosScreen({super.key});

  @override
  State<OrdenosScreen> createState() => _OrdenosScreenState();
}

class _OrdenosScreenState extends State<OrdenosScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _ordenos = [];
  bool _isLoading = true;
  int? _fincaId;
  String _fincaNombre = 'Cargando...';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      print('DEBUG: [Ordenos] Iniciando carga de datos iniciales...');
      final userRes = await _apiService.getMe();
      print('DEBUG: [Ordenos] Status getMe: ${userRes.statusCode}');
      
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        final user = userData['response'] ?? userData;
        final int usuarioId = user['usuarioId'];
        print('DEBUG: [Ordenos] usuarioId: $usuarioId');

        final producersRes = await _apiService.getEntity('productores');
        print('DEBUG: [Ordenos] Status productores: ${producersRes.statusCode}');
        
        if (producersRes.statusCode == 200) {
          final producersData = jsonDecode(producersRes.body);
          final List<dynamic> producers = producersData['response'] ?? (producersData is List ? producersData : []);
          final productor = producers.firstWhere((p) => p['usuarioId'] == usuarioId, orElse: () => null);

          if (productor != null) {
            final int productorId = productor['productorId'];
            print('DEBUG: [Ordenos] productorId: $productorId');

            final fincasRes = await _apiService.getEntity('fincas');
            print('DEBUG: [Ordenos] Status fincas: ${fincasRes.statusCode}');
            
            if (fincasRes.statusCode == 200) {
              final fincasData = jsonDecode(fincasRes.body);
              final List<dynamic> fincas = fincasData['response'] ?? (fincasData is List ? fincasData : []);
              final finca = fincas.firstWhere((f) => f['productorId'] == productorId, orElse: () => null);

              if (finca != null) {
                setState(() {
                  _fincaId = finca['fincaId'];
                  _fincaNombre = finca['nombre'] ?? 'Finca';
                });
                print('DEBUG: [Ordenos] fincaId encontrado: $_fincaId');
                await _loadOrdenos();
              } else {
                print('DEBUG: [Ordenos] No se encontró finca para productor $productorId');
                setState(() {
                  _fincaNombre = 'N/A';
                  _isLoading = false;
                });
              }
            } else {
              print('DEBUG: [Ordenos] Error al cargar fincas: ${fincasRes.statusCode}');
              setState(() => _isLoading = false);
            }
          } else {
            print('DEBUG: [Ordenos] No se encontró productor para usuario $usuarioId');
            setState(() {
              _fincaNombre = 'N/A';
              _isLoading = false;
            });
          }
        } else {
          print('DEBUG: [Ordenos] Error al cargar productores: ${producersRes.statusCode}');
          setState(() => _isLoading = false);
        }
      } else {
        print('DEBUG: [Ordenos] Error en getMe: ${userRes.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('DEBUG: [Ordenos] Excepción en _loadInitialData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrdenos() async {
    if (_fincaId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final url = 'ordenos/por-finca/$_fincaId';
      print('DEBUG: [Ordenos] Consultando en: $url');
      final response = await _apiService.getEntity(url);
      print('DEBUG: [Ordenos] Respuesta Ordeños [${response.statusCode}]: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> list = [];

        if (data is List) {
          list = data;
        } else if (data is Map) {
          // Si el servidor devuelve un solo objeto en lugar de una lista, lo envolvemos
          if (data.containsKey('ordenoId')) {
            list = [data];
          } else {
            // Buscamos dentro de envoltorios comunes
            dynamic nested = data['response'] ?? data['data'] ?? data;
            if (nested is List) {
              list = nested;
            } else if (nested is Map) {
              if (nested.containsKey('data') && nested['data'] is List) {
                list = nested['data'];
              } else if (nested.containsKey('ordenoId')) {
                list = [nested];
              }
            }
          }
        }

        setState(() {
          _ordenos = list;
          _isLoading = false;
        });
      } else {
        print('DEBUG: [Ordenos] Error al cargar ordeños: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('DEBUG: [Ordenos] Error en _loadOrdenos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _goToNewOrdeno() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewOrdenoScreen(
          fincaId: _fincaId!,
          fincaNombre: _fincaNombre,
        ),
      ),
    );
    if (result == true) {
      setState(() => _isLoading = true);
      _loadOrdenos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Mis ordeños', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: _fincaId != null ? _goToNewOrdeno : null,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Nuevo ordeño', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _ordenos.isEmpty
                        ? const Center(child: Text('No hay ordeños registrados'))
                        : RefreshIndicator(
                            onRefresh: _loadOrdenos,
                            child: ListView.builder(
                              itemCount: _ordenos.length,
                              itemBuilder: (context, index) {
                                final o = _ordenos[index];
                                final String ordenoCustomName = 'ORD-$_fincaNombre-${o['ordenoId']}';
                                final dateStr = o['fechaHoraFin']?.toString() ?? o['fechaHoraInicio']?.toString();
                                String formattedDate = 'Fecha no disponible';
                                
                                if (dateStr != null) {
                                  try {
                                    final date = DateTime.parse(dateStr).toLocal();
                                    formattedDate = "${date.day} de ${_getMonthName(date.month)} de ${date.year}";
                                  } catch (e) {
                                    print('DEBUG: Error parseando fecha: $e');
                                  }
                                }
                                
                                return GestureDetector(
                                  onTap: () => _showQrDialog(o['ordenoId'], ordenoCustomName),
                                  child: Container(
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
                                              Text(ordenoCustomName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                              const SizedBox(height: 4),
                                              Text(formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                              const SizedBox(height: 4),
                                              Text('${o['volumenLitros']} L', style: const TextStyle(color: Colors.grey)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.qr_code_2, color: Colors.blueAccent, size: 30),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQrDialog(int ordenoId, String customName) {
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
                data: jsonEncode({"type": "ordeno", "id": ordenoId, "name": customName}),
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

  String _getMonthName(int month) {
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return months[month - 1];
  }
}

class NewOrdenoScreen extends StatefulWidget {
  final int fincaId;
  final String fincaNombre;

  const NewOrdenoScreen({super.key, required this.fincaId, required this.fincaNombre});

  @override
  State<NewOrdenoScreen> createState() => _NewOrdenoScreenState();
}

class _NewOrdenoScreenState extends State<NewOrdenoScreen> {
  final _volumeController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Nuevo ordeño', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Registrar ordeño', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Text('Finca: ${widget.fincaNombre}', style: const TextStyle(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 20),
                const Text('Volumen capturado (litros)', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 8),
                TextField(
                  controller: _volumeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Ej: 150.5',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: (_isLoading || _volumeController.text.isEmpty) ? null : _saveOrdeno,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.4), // Light blue as in mockup
                    disabledBackgroundColor: Colors.blueAccent.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Registrar ordeño', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                ),
                const SizedBox(height: 15),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveOrdeno() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toIso8601String();
      final body = {
        "fechaHoraInicio": now,
        "fechaHoraFin": now,
        "volumenLitros": double.parse(_volumeController.text),
        "fincaId": widget.fincaId
      };

      print('DEBUG: Guardando Ordeño: $body');
      final res = await _apiService.registerEntity('ordenos', body);
      print('DEBUG: Respuesta Ordeño [${res.statusCode}]: ${res.body}');

      if (res.statusCode == 200 || res.statusCode == 201) {
        final responseData = jsonDecode(res.body);
        final dynamic resp = responseData['response'];
        
        // Manejo de la estructura anidada para obtener el ID
        int? newOrdenoId;
        if (resp is Map) {
          if (resp.containsKey('data') && resp['data'] is Map) {
            newOrdenoId = resp['data']['ordenoId'];
          } else {
            newOrdenoId = resp['ordenoId'];
          }
        }

        if (newOrdenoId == null) {
          throw Exception('No se pudo obtener el ID del ordeño creado');
        }
        
        // --- DOBLE CONSULTA: Crear el Lote automáticamente ---
        print('DEBUG: Intentando crear Lote automáticamente para Ordeño #$newOrdenoId');
        
        final loteBody = {
          "ordenoId": newOrdenoId,
          "centroAcopioId": null,
          "volumenCapturadoLitros": double.parse(_volumeController.text),
          "transporteId": null
        };

        final loteRes = await _apiService.registerEntity('lotes', loteBody);
        print('DEBUG: Respuesta Creación Lote [${loteRes.statusCode}]: ${loteRes.body}');

        if (mounted) {
          if (loteRes.statusCode == 200 || loteRes.statusCode == 201) {
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ordeño guardado, pero falló la creación del lote.'), backgroundColor: Colors.orange),
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        if (mounted) {
          final errorData = jsonDecode(res.body);
          String msg = errorData['response']?['message'] ?? errorData['errors']?.toString() ?? 'Error al guardar';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
