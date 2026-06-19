import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';
import 'worker_detail_screen.dart';

class WorkersScreen extends StatefulWidget {
  final String acopioNombre;

  const WorkersScreen({super.key, required this.acopioNombre});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchWorkers();
  }

  Future<void> _fetchWorkers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getEntity('usuarios');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allUsers = data['response'] ?? data;
        
        setState(() {
          // Filtramos por centroAcopioNombre y que sean trabajadores
          _workers = allUsers.where((u) => 
            u['centroAcopioNombre'] == widget.acopioNombre && 
            ((u['tipoUsuario']?.toString().toLowerCase().contains('trabajador') ?? false) ||
             (u['rolNombre']?.toString().toLowerCase().contains('trabajador') ?? false))
          ).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Error al cargar usuarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar trabajadores: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trabajadores'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      extendBodyBehindAppBar: true,
      body: CowBackground(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _workers.isEmpty
                ? const Center(child: Text('No hay trabajadores inscritos'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
                    itemCount: _workers.length,
                    itemBuilder: (context, index) {
                      final worker = _workers[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 2,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            child: const Icon(Icons.person, color: Colors.blue),
                          ),
                          title: Text(
                            worker['nombre'] ?? worker['email'] ?? 'Sin nombre',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(worker['tipoUsuario'] ?? worker['rolNombre'] ?? 'Trabajador'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WorkerDetailScreen(worker: worker),
                              ),
                            );
                            if (result == true) {
                              _fetchWorkers(); // Recargar si hubo cambios
                            }
                          },
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar agregar trabajador
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Funcionalidad para agregar trabajador próximamente')),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
