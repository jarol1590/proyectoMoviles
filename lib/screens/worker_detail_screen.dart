import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';

class WorkerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> worker;

  const WorkerDetailScreen({super.key, required this.worker});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  final ApiService _apiService = ApiService();
  late Map<String, dynamic> _currentWorker;

  @override
  void initState() {
    super.initState();
    _currentWorker = widget.worker;
  }

  void _confirmDelete() {
    final displayName = _currentWorker['nombre'] ?? _currentWorker['email'] ?? 'este trabajador';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Trabajador'),
        content: Text('¿Estás seguro de que deseas eliminar a $displayName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteWorker();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteWorker() async {
    try {
      final response = await _apiService.deleteEntity('usuarios', _currentWorker['usuarioId']);
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trabajador eliminado correctamente')),
          );
          Navigator.pop(context, true); // Retornar true para indicar que se debe recargar la lista
        }
      } else {
        throw Exception('Error al eliminar trabajador');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Trabajador'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      extendBodyBehindAppBar: true,
      body: CowBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(Icons.person, size: 50, color: Colors.blue),
                ),
              ),
              const SizedBox(height: 24),
              _buildInfoSection('Información de Usuario', [
                _buildInfoTile(Icons.person_outline, 'Nombre', _currentWorker['nombre'] ?? _currentWorker['email']?.split('@')[0] ?? 'No disponible'),
                _buildInfoTile(Icons.email_outlined, 'Email', _currentWorker['email']),
                _buildInfoTile(Icons.badge_outlined, 'Rol', _currentWorker['rolNombre'] ?? _currentWorker['tipoUsuario'] ?? 'Trabajador'),
                _buildInfoTile(Icons.calendar_today_outlined, 'Estado', _currentWorker['estado'] ?? 'Activo'),
              ]),
              const SizedBox(height: 16),
              _buildInfoSection('Centro de Acopio', [
                _buildInfoTile(Icons.business_outlined, 'Centro', _currentWorker['centroAcopioNombre'] ?? 'No asignado'),
                _buildInfoTile(Icons.event_outlined, 'Fecha Creación', _currentWorker['fechaCreacion']?.toString().split('T')[0] ?? 'No disponible'),
              ]),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implementar edición
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edición próximamente')),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Borrar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
