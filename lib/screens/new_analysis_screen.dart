import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';

class NewAnalysisScreen extends StatefulWidget {
  final Map<String, dynamic> sample;
  final String loteName;
  final int centroAcopioId;

  const NewAnalysisScreen({
    super.key,
    required this.sample,
    required this.loteName,
    required this.centroAcopioId,
  });

  @override
  State<NewAnalysisScreen> createState() => _NewAnalysisScreenState();
}

class _NewAnalysisScreenState extends State<NewAnalysisScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _observationsController = TextEditingController();
  
  List<dynamic> _parameters = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<int, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadParameters();
  }

  Future<void> _loadParameters() async {
    try {
      final response = await _apiService.getEntity('parametros-calidad/centro/${widget.centroAcopioId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _parameters = data['response'] ?? data;
          for (var p in _parameters) {
            _controllers[p['parametroId']] = TextEditingController();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar parámetros: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitAnalysis() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      // 1. Crear el Análisis Principal
      final analysisPayload = {
        'muestraId': widget.sample['muestraId'],
        'fechaHoraAnalisis': DateTime.now().toIso8601String(),
        'observaciones': _observationsController.text,
      };

      print('DEBUG: Creando análisis principal...');
      final analysisRes = await _apiService.registerEntity('analisis-calidad', analysisPayload);
      print('DEBUG: Respuesta Analisis [${analysisRes.statusCode}]: ${analysisRes.body}');

      if (analysisRes.statusCode == 200 || analysisRes.statusCode == 201) {
        final analysisData = jsonDecode(analysisRes.body);
        final createdAnalysis = analysisData['response'] ?? analysisData;
        final int analysisId = createdAnalysis['analisisId'];

        // 2. Registrar cada resultado de parámetro
        bool allParamsSaved = true;
        for (var p in _parameters) {
          final int paramId = p['parametroId'];
          final double valor = double.tryParse(_controllers[paramId]!.text) ?? 0.0;
          
          final resultPayload = {
            "analisisId": analysisId,
            "parametroId": paramId,
            "valorResultado": valor,
            "observacion": _observationsController.text // Opcional, enviamos la misma obs
          };

          print('DEBUG: Registrando parámetro $paramId...');
          final resultRes = await _apiService.registerEntity('resultados-parametro', resultPayload);
          if (resultRes.statusCode != 200 && resultRes.statusCode != 201) {
            allParamsSaved = false;
            print('DEBUG: Error al guardar parámetro $paramId: ${resultRes.body}');
          }
        }

        if (mounted) {
          if (allParamsSaved) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Análisis y resultados registrados con éxito')));
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Análisis creado, pero algunos parámetros no se guardaron.'), backgroundColor: Colors.orange)
            );
            Navigator.pop(context, true);
          }
        }
      } else {
        throw Exception('Error al crear el análisis principal: ${analysisRes.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _observationsController.dispose();
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Nuevo análisis', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.loteName} — Muestra #${widget.sample['muestraId']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Ingresa los valores del análisis',
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    const SizedBox(height: 32),
                    ..._parameters.map((p) => _buildParameterField(p)).toList(),
                    _buildObservationsField(),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _submitAnalysis,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2EB872),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Registrar análisis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildParameterField(dynamic p) {
    final int id = p['parametroId'];
    final String name = p['nombre'];
    final String unit = p['unidad'] ?? '';
    final String range = 'Óptimo: ${p['valorMinimo']} - ${p['valorMaximo']}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              children: [
                TextSpan(text: name),
                if (unit.isNotEmpty) TextSpan(text: ' ($unit)', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.normal, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _controllers[id],
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: range,
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildObservationsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Observaciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        TextFormField(
          controller: _observationsController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Notas adicionales sobre el análisis...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
