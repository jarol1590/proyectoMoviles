import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';
import 'worker_detail_screen.dart';

class WorkersManagementScreen extends StatefulWidget {
  final int centroAcopioId;
  const WorkersManagementScreen({super.key, required this.centroAcopioId});

  @override
  State<WorkersManagementScreen> createState() => _WorkersManagementScreenState();
}

class _WorkersManagementScreenState extends State<WorkersManagementScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _workers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() => _isLoading = true);
    try {
      // Obtenemos todos los usuarios y filtramos por centroAcopioId y Rol Trabajador (4)
      final response = await _apiService.getEntity('usuarios');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allUsers = data['response'] ?? data;
        
        setState(() {
          _workers = allUsers.where((u) {
            final matchesCenter = u['centroAcopio']?['centroAcopioId'] == widget.centroAcopioId;
            final isWorker = (u['roles'] as List?)?.any((r) => r['rolId'] == 4) ?? false;
            // También revisamos si el tipoUsuario indica que es trabajador
            final isWorkerType = u['tipoUsuario']?.toString().toLowerCase().contains('trabajador') ?? false;
            
            return matchesCenter && (isWorker || isWorkerType);
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading workers: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Trabajadores', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _workers.isEmpty
                ? _buildEmptyState()
                : _buildList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No hay trabajadores inscritos.', style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _workers.length,
      itemBuilder: (context, index) {
        final worker = _workers[index];
        final String name = worker['trabajador']?['nombre'] ?? worker['nombre'] ?? 'Sin nombre';
        final String email = worker['email'] ?? 'Sin correo';

        return GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WorkerDetailScreen(worker: worker),
              ),
            );
            if (result == true) _loadWorkers();
          },
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
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  child: const Icon(Icons.person, color: Colors.blueAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        );
      },
    );
  }
}
