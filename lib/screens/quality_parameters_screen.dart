import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';

class QualityParametersScreen extends StatefulWidget {
  final int centroAcopioId;
  const QualityParametersScreen({super.key, required this.centroAcopioId});

  @override
  State<QualityParametersScreen> createState() => _QualityParametersScreenState();
}

class _QualityParametersScreenState extends State<QualityParametersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _parameters = [];
  bool _isLoading = true;

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
          _parameters.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading parameters: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _moveParameter(int index, int direction) async {
    if (index + direction < 0 || index + direction >= _parameters.length) return;

    final current = _parameters[index];
    final other = _parameters[index + direction];

    final tempOrder = current['orden'];
    current['orden'] = other['orden'];
    other['orden'] = tempOrder;

    setState(() => _isLoading = true);

    try {
      await _apiService.updateEntity('parametros-calidad', current['parametroId'], current);
      await _apiService.updateEntity('parametros-calidad', other['parametroId'], other);
      await _loadParameters();
    } catch (e) {
      print('Error moving parameter: $e');
      _loadParameters();
    }
  }

  Future<void> _deleteParameter(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar parámetro'),
        content: const Text('¿Estás seguro de que deseas eliminar este parámetro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        print('DEBUG: Eliminando parámetro ID: $id');
        final res = await _apiService.deleteEntity('parametros-calidad', id);
        print('DEBUG: Respuesta DELETE parámetro [${res.statusCode}]: ${res.body}');
        
        if (res.statusCode == 200 || res.statusCode == 204) {
          await _loadParameters();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: ${res.statusCode}'))
          );
          setState(() => _isLoading = false);
        }
      } catch (e) {
        print('Error deleting parameter: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Parámetros de calidad', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _parameters.isEmpty
              ? _buildEmptyState()
              : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: const Color(0xFF3482B9),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.science_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text('No hay parámetros definidos.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          Text('Agrega el primero.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _parameters.length,
      itemBuilder: (context, index) {
        final p = _parameters[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${p['orden']}', style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p['nombre'],
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unidad: ${p['unidad']}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                    const SizedBox(height: 4),
                    Text('Rango óptimo: ${p['valorMinimo']} - ${p['valorMaximo']}', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildCardAction(Icons.keyboard_arrow_up, () => _moveParameter(index, -1), enabled: index > 0),
                  _buildCardAction(Icons.keyboard_arrow_down, () => _moveParameter(index, 1), enabled: index < _parameters.length - 1),
                  const SizedBox(width: 8),
                  _buildCardAction(Icons.edit_outlined, () => _openForm(parameter: p), color: const Color(0xFF3482B9)),
                  _buildCardAction(Icons.delete_outline, () => _deleteParameter(p['parametroId']), color: const Color(0xFFE57373)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildCardAction(IconData icon, VoidCallback? onPressed, {Color color = Colors.grey, bool enabled = true}) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: enabled ? color : Colors.grey[300], size: 24),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
    );
  }

  void _openForm({Map<String, dynamic>? parameter}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ParameterFormScreen(
          centroAcopioId: widget.centroAcopioId,
          parameter: parameter,
          nextOrder: _parameters.length + 1,
        ),
      ),
    );
    if (result == true) {
      _loadParameters();
    }
  }
}

class ParameterFormScreen extends StatefulWidget {
  final int centroAcopioId;
  final Map<String, dynamic>? parameter;
  final int nextOrder;

  const ParameterFormScreen({
    super.key,
    required this.centroAcopioId,
    this.parameter,
    required this.nextOrder,
  });

  @override
  State<ParameterFormScreen> createState() => _ParameterFormScreenState();
}

class _ParameterFormScreenState extends State<ParameterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _unitController;
  late TextEditingController _minController;
  late TextEditingController _maxController;
  late TextEditingController _orderController;
  late TextEditingController _descController;
  
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.parameter?['nombre'] ?? '');
    _unitController = TextEditingController(text: widget.parameter?['unidad'] ?? '');
    _minController = TextEditingController(text: widget.parameter?['valorMinimo']?.toString() ?? '');
    _maxController = TextEditingController(text: widget.parameter?['valorMaximo']?.toString() ?? '');
    _orderController = TextEditingController(text: widget.parameter?['orden']?.toString() ?? widget.nextOrder.toString());
    _descController = TextEditingController(text: widget.parameter?['descripcion'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _orderController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final data = {
      "centroAcopioId": widget.centroAcopioId,
      "nombre": _nameController.text,
      "unidad": _unitController.text,
      "valorMinimo": double.tryParse(_minController.text) ?? 0,
      "valorMaximo": double.tryParse(_maxController.text) ?? 0,
      "descripcion": _descController.text,
      "orden": int.tryParse(_orderController.text) ?? 1,
    };

    try {
      final response = widget.parameter == null
          ? await _apiService.registerEntity('parametros-calidad', data)
          : await _apiService.updateEntity('parametros-calidad', widget.parameter!['parametroId'], data);

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 204) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al guardar parámetro')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Parámetros de calidad', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.parameter == null ? 'Nuevo parámetro' : 'Editar parámetro',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              const SizedBox(height: 24),
              _buildField('Nombre *', _nameController, hint: 'Acidez'),
              _buildField('Unidad', _unitController, hint: 'Ph'),
              _buildField('Valor mínimo óptimo', _minController, hint: '1', keyboardType: TextInputType.number),
              _buildField('Valor máximo óptimo', _maxController, hint: '2.5', keyboardType: TextInputType.number),
              _buildField('Orden', _orderController, hint: '1', keyboardType: TextInputType.number),
              _buildField('Descripción / Instrucción', _descController, hint: 'Describe qué debe medir el trabajador...', isLong: true),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE0E0E0),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3482B9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint, bool isLong = false, TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF555555), fontSize: 15)),
          const SizedBox(height: 10),
          TextFormField(
            controller: controller,
            maxLines: isLong ? 4 : 1,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: const Color(0xFFF5F7F8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: Color(0xFF3482B9), width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            validator: (v) => (v == null || v.isEmpty) && label.contains('*') ? 'Este campo es requerido' : null,
          ),
        ],
      ),
    );
  }
}
