import 'dart:convert';
import 'package:flutter/material.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _productorData;
  Map<String, dynamic>? _fincaData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullProfile();
  }

  Future<void> _loadFullProfile() async {
    try {
      // 1. Obtener datos básicos del usuario
      final userRes = await _apiService.getMe();
      if (userRes.statusCode == 200) {
        final userData = jsonDecode(userRes.body);
        _userData = userData['response'] ?? userData;
        final int usuarioId = _userData!['usuarioId'];

        // 2. Obtener información detallada del productor
        final producersRes = await _apiService.getEntity('productores');
        if (producersRes.statusCode == 200) {
          final producersData = jsonDecode(producersRes.body);
          final List<dynamic> producers = producersData['response'] ?? producersData;
          
          // Buscamos el productor que corresponda a este usuarioId
          try {
            _productorData = producers.firstWhere((p) => p['usuarioId'] == usuarioId);
          } catch (_) {
            _productorData = null;
          }
        }

        // 3. Obtener información de la finca
        if (_productorData != null) {
          final fincasRes = await _apiService.getEntity('fincas');
          if (fincasRes.statusCode == 200) {
            final fincasData = jsonDecode(fincasRes.body);
            final List<dynamic> fincas = fincasData['response'] ?? fincasData;
            
            // Buscamos la finca que pertenezca a este productorId
            try {
              _fincaData = fincas.firstWhere((f) => f['productorId'] == _productorData!['productorId']);
            } catch (_) {
              _fincaData = null;
            }
          }
        }
      }
    } catch (e) {
      print('Error loading full profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _logout() async {
    await _apiService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userData == null) {
      return const Center(child: Text('Error al cargar perfil'));
    }

    // Mapeo de datos obtenidos
    final String nombre = _productorData?['nombre'] ?? _userData!['nombre'] ?? 'Sin nombre';
    final String email = _userData!['email'] ?? 'Sin email';
    final String documento = _productorData?['documento'] ?? 'N/A';
    final String telefono = _productorData?['telefono'] ?? 'N/A';
    
    final String nombreFinca = _fincaData?['nombre'] ?? 'N/A';
    final String direccionFinca = _fincaData?['direccion'] ?? 'N/A';

    return CowBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Mi Perfil', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              _buildInfoSection('Información Personal', [
                _buildInfoRow(Icons.person_outline, 'Nombre', nombre),
                _buildInfoRow(Icons.badge_outlined, 'Documento', documento),
                _buildInfoRow(Icons.phone_android_outlined, 'Teléfono', telefono),
                _buildInfoRow(Icons.mail_outline, 'Correo', email),
              ]),
              
              const SizedBox(height: 20),
              
              _buildInfoSection('Información de la Finca', [
                _buildInfoRow(Icons.eco_outlined, 'Finca', nombreFinca),
                _buildInfoRow(Icons.location_on_outlined, 'Dirección', direccionFinca),
              ]),
              
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 20),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          const Divider(),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
