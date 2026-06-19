import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';
import 'lotes_screen.dart';
import 'ordenos_screen.dart';
import 'profile_screen.dart';
import 'quality_parameters_screen.dart';
import 'login_screen.dart';
import 'workers_screen.dart';
import 'select_batch_screen.dart';
import 'qr_scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final ApiService _apiService = ApiService();
  String _userName = 'Cargando...';
  String _userRole = ''; // 'productor', 'centro_acopio', 'trabajador'
  Map<String, dynamic>? _roleData;
  Map<String, dynamic>? _acopioData;
  int _fincaId = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() async {
    try {
      final response = await _apiService.getMe().timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userData = data['response'] ?? data;
        
        if (mounted) {
          setState(() {
            String tipo = (userData['tipoUsuario'] ?? userData['rol']?['nombre'] ?? '').toString().toLowerCase();

            if (tipo.contains('trabajador')) {
              _userRole = 'trabajador';
              _userName = userData['trabajador']?['nombre'] ?? userData['nombre'] ?? 'Trabajador';
              _roleData = userData['trabajador'];
              _acopioData = userData['centroAcopio'];
            } else if (tipo.contains('acopio')) {
              _userRole = 'centro_acopio';
              _userName = userData['centroAcopio']?['nombre'] ?? userData['nombre'] ?? 'Centro';
              _roleData = userData['centroAcopio'];
            } else {
              _userRole = 'productor';
              _userName = userData['productor']?['nombre'] ?? userData['nombre'] ?? 'Usuario';
              _roleData = userData['productor'];
            }
          });

          // Si es productor, buscamos su fincaId real
          if (_userRole == 'productor') {
            final fincasRes = await _apiService.getEntity('fincas');
            if (fincasRes.statusCode == 200) {
              final fincasData = jsonDecode(fincasRes.body);
              final List<dynamic> fincas = fincasData['response'] ?? fincasData;
              final finca = fincas.firstWhere(
                (f) => f['productorId'] == _roleData?['productorId'],
                orElse: () => null
              );
              if (finca != null && mounted) {
                setState(() {
                  _fincaId = finca['fincaId'];
                });
              } else if (mounted) {
                setState(() => _fincaId = 11);
              }
            }
          }
        }
      } else if (response.statusCode == 401) {
        _logout();
      }
    } catch (e) {
      if (mounted) setState(() {
        _userRole = 'productor';
        _userName = 'Usuario';
        _fincaId = 11;
      });
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
    if (_userRole == '') {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    Widget content;
    if (_selectedIndex == 0) {
      if (_userRole == 'centro_acopio') {
        content = AcopioHome(
          acopioName: _userName, 
          address: _roleData?['direccion'] ?? 'Dirección no disponible',
          onLogout: _logout,
          centroAcopioId: _roleData?['centroAcopioId'] ?? 0,
        );
      } else if (_userRole == 'trabajador') {
        content = WorkerHome(
          workerName: _userName,
          acopioName: _acopioData?['nombre'] ?? 'Centro de acopio',
          acopioAddress: _acopioData?['direccion'] ?? 'Dirección no disponible',
          onLogout: _logout,
          centroAcopioId: _acopioData?['centroAcopioId'] ?? 0,
        );
      } else {
        content = ProducerHome(
          userName: _userName, 
          fincaId: _fincaId,
        );
      }
    } else if (_selectedIndex == 2 && _userRole == 'centro_acopio') {
      content = WorkersScreen(acopioNombre: _userName);
    } else if (_selectedIndex == 1 && _userRole == 'productor') {
      content = const OrdenosScreen();
    } else if (_selectedIndex == 2 && _userRole == 'productor') {
      content = const LotesScreen();
    } else if (_selectedIndex == 3 && _userRole == 'productor') {
      content = const ProfileScreen();
    } else if (_selectedIndex == 3 && _userRole == 'trabajador') {
      content = const QrScannerScreen();
    } else {
      content = Center(child: Text('Pantalla ${_selectedIndex + 1} - Cascarón'));
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    if (_userRole == 'centro_acopio') {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: _buildCowButton(),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.group_outlined), label: 'Trabajadores'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: (index) => setState(() => _selectedIndex = index),
      );
    } else if (_userRole == 'trabajador') {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(icon: Icon(Icons.local_fire_department_outlined), label: 'R. Regional'),
          BottomNavigationBarItem(
            icon: _buildCowButton(),
            label: '',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.qr_code_2), label: 'QR'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.black,
        onTap: (index) => setState(() => _selectedIndex = index),
      );
    }

    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        const BottomNavigationBarItem(icon: Icon(Icons.water_drop_outlined), label: 'Ordeño'),
        BottomNavigationBarItem(icon: _buildCowButton(), label: ''),
        const BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Lotes'),
        const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'User'),
      ],
      currentIndex: _selectedIndex > 1 ? _selectedIndex + 1 : _selectedIndex,
      selectedItemColor: Colors.black,
      onTap: (index) {
        if (index == 2) return;
        int adjustedIndex = index > 2 ? index - 1 : index;
        setState(() => _selectedIndex = adjustedIndex);
      },
    );
  }

  Widget _buildCowButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey[300]!, width: 2)),
      child: const CircleAvatar(radius: 18, backgroundColor: Colors.white, child: Text('🐮', style: TextStyle(fontSize: 20))),
    );
  }
}

class ProducerHome extends StatefulWidget {
  final String userName;
  final int fincaId;

  const ProducerHome({
    super.key, 
    required this.userName,
    required this.fincaId,
  });

  @override
  State<ProducerHome> createState() => _ProducerHomeState();
}

class _ProducerHomeState extends State<ProducerHome> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _lastAnalysis;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.fincaId != 0) {
      _fetchLastAnalysis();
    }
  }

  @override
  void didUpdateWidget(ProducerHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fincaId != oldWidget.fincaId && widget.fincaId != 0) {
      _fetchLastAnalysis();
    }
  }

  Future<void> _fetchLastAnalysis() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getEntity('analisis-calidad/por-finca/${widget.fincaId}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> analyses = data['response'] ?? (data is List ? data : []);
        if (analyses.isNotEmpty) {
          setState(() {
            _lastAnalysis = analyses.reduce((curr, next) => 
              (curr['analisisId'] ?? 0) > (next['analisisId'] ?? 0) ? curr : next
            );
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) return '¡Buenos días!';
    if (hour >= 12 && hour < 18) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(widget.userName),
            const SizedBox(height: 24),
            _isLoading 
              ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
              : _lastAnalysis != null 
                ? _buildAnalysisSection(_lastAnalysis!, widget.userName)
                : _buildEmptyAnalysis(),
            const SizedBox(height: 16),
            _buildCalendarSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        const CircleAvatar(radius: 25, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_getGreeting(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(name, style: const TextStyle(color: Colors.grey)),
        ]),
      ]),
      Row(children: [_buildIconButton(Icons.qr_code_scanner), const SizedBox(width: 8), _buildIconButton(Icons.notifications_none)])
    ]);
  }

  Widget _buildIconButton(IconData icon) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: Colors.black54));
  }

  Widget _buildEmptyAnalysis() {
    return _buildSectionCard(
      title: 'Último análisis', 
      child: const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('No hay análisis registrados para esta finca', style: TextStyle(color: Colors.grey)),
        ),
      )
    );
  }

  Widget _buildCalendarSection() {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('📅 Calendario de actividades', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), TableCalendar(firstDay: DateTime.utc(2020, 1, 1), lastDay: DateTime.utc(2030, 12, 31), focusedDay: DateTime.now(), calendarFormat: CalendarFormat.month, headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true), calendarStyle: CalendarStyle(todayDecoration: BoxDecoration(color: Colors.blue.withOpacity(0.5), shape: BoxShape.circle), selectedDecoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)))]));
  }
}

class AcopioHome extends StatelessWidget {
  final String acopioName;
  final String address;
  final VoidCallback onLogout;
  final int centroAcopioId;
  const AcopioHome({
    super.key,
    required this.acopioName,
    required this.address,
    required this.onLogout,
    required this.centroAcopioId,
  });

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoleHeader('Centro de acopio', acopioName, onLogout, Icons.business),
            const SizedBox(height: 24),
            _buildInfoCard(acopioName, address, Icons.business),
            const SizedBox(height: 24),
            const Text('Gestión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QualityParametersScreen(centroAcopioId: centroAcopioId),
                  ),
                );
              },
              child: _buildActionCard(
                'Parámetros de calidad',
                'Agregar, editar o quitar campos del formulario',
                Icons.science_outlined,
                Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Calendario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildEmptyCalendar(),
          ],
        ),
      ),
    );
  }
}

class WorkerHome extends StatelessWidget {
  final String workerName;
  final String acopioName;
  final String acopioAddress;
  final VoidCallback onLogout;
  final int centroAcopioId;

  const WorkerHome({
    super.key,
    required this.workerName,
    required this.acopioName,
    required this.acopioAddress,
    required this.onLogout,
    required this.centroAcopioId,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 0 && hour < 12) return '¡Buenos días!';
    if (hour >= 12 && hour < 18) return '¡Buenas tardes!';
    return '¡Buenas noches!';
  }

  @override
  Widget build(BuildContext context) {
    return CowBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(workerName, onLogout),
            const SizedBox(height: 24),
            _buildInfoCard(acopioName, acopioAddress, Icons.business),
            const SizedBox(height: 24),
            const Text('Gestión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SelectBatchScreen(centroAcopioId: centroAcopioId),
                  ),
                );
              },
              child: _buildActionCard('Nuevo análisis', 'Registrar valores de calidad para un lote', Icons.auto_graph, Colors.green),
            ),
            const SizedBox(height: 12),
            _buildActionCard('Transportes', 'Ver transportes abiertos y completados', Icons.directions_car_filled_outlined, Colors.orange),
            const SizedBox(height: 24),
            const Text('Calendario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildEmptyCalendar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String name, VoidCallback onLogout) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        const CircleAvatar(radius: 25, backgroundColor: Colors.grey, child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_getGreeting(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(name, style: const TextStyle(color: Colors.grey)),
        ]),
      ]),
      Row(children: [
        IconButton(onPressed: onLogout, icon: const Icon(Icons.logout, color: Colors.redAccent)),
        const SizedBox(width: 8), 
        _buildIconButton(Icons.notifications_none)
      ])
    ]);
  }

  Widget _buildIconButton(IconData icon) {
    return Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 24, color: Colors.black54));
  }
}

// Global helper widgets for Analysis to avoid duplication
Widget _buildAnalysisSection(Map<String, dynamic> analysis, String contextName) {
  final results = analysis['resultados'] as List<dynamic>? ?? [];
  final dateStr = analysis['fechaAnalisis'];
  String dateFormatted = "Fecha no disponible";
  if (dateStr != null) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      dateFormatted = "${date.day} de ${_getMonthName(date.month)} de ${date.year}";
    } catch (e) {
      dateFormatted = dateStr.toString().split('T')[0];
    }
  }
  
  final fincaName = analysis['fincaNombre'] ?? 'Finca';
  final loteId = analysis['loteId'];
  final titleInfo = "$dateFormatted — $fincaName${loteId != null ? " (Lote #$loteId)" : ""}";

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _buildSectionCard(
        title: '',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(titleInfo, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            ...results.map((res) => _buildAnalysisRow(
              res['parametroNombre'], 
              '${res['valorResultado']} ${res['unidad'] ?? ""}',
              res['dentroDeRango'] ?? true
            )).toList(),
          ]
        )
      ),
      const SizedBox(height: 24),
      const Text('Parámetros evaluados', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      SizedBox(
        height: 180, 
        child: results.isEmpty 
          ? const Center(child: Text('No hay parámetros detallados', style: TextStyle(color: Colors.grey, fontSize: 12)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final res = results[index];
                double val = (res['valorResultado'] ?? 0.0).toDouble();
                double max = (res['valorMaximo'] ?? 0.0).toDouble();
                double progress = max > 0 ? (val / max).clamp(0.0, 1.0) : (val > 0 ? 1.0 : 0.0);
                String percent = "${(progress * 100).toInt()}%";
                bool success = res['dentroDeRango'] ?? true;
                
                return _buildParameterCard(
                  percent, 
                  res['parametroNombre'], 
                  '${res['valorResultado']} ${res['unidad'] ?? ""}', 
                  '${res['valorMinimo']} - ${res['valorMaximo']}${res['unidad'] ?? ""}', 
                  progress,
                  success
                );
              },
            ),
      ),
    ],
  );
}

Widget _buildSectionCard({required String title, required Widget child}) {
  return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (title.isNotEmpty) Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), if (title.isNotEmpty) const SizedBox(height: 12), child]));
}

Widget _buildAnalysisRow(String label, String value, bool success) {
  return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey[50]!, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(Icons.circle, size: 10, color: success ? Colors.green : Colors.red), const SizedBox(width: 8), Text(label, style: const TextStyle(fontSize: 14)), const Spacer(), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))])));
}

Widget _buildParameterCard(String percent, String label, String value, String optimal, double progress, bool success) {
  return Container(width: 140, margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)), child: Column(children: [Stack(alignment: Alignment.center, children: [SizedBox(width: 70, height: 70, child: CircularProgressIndicator(value: progress, strokeWidth: 8, backgroundColor: Colors.grey[100], valueColor: AlwaysStoppedAnimation<Color>(success ? Colors.green : Colors.red))), Text(percent, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: success ? Colors.green : Colors.red))]), const SizedBox(height: 12), Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(value, style: const TextStyle(fontSize: 12, color: Colors.grey)), const SizedBox(height: 4), Text('Óptimo: $optimal', style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center)]));
}

String _getMonthName(int month) {
  const months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
  return months[month - 1];
}

Widget _buildRoleHeader(String roleLabel, String name, VoidCallback onLogout, IconData roleIcon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
    child: Row(
      children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)), child: Icon(roleIcon, color: Colors.grey)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(roleLabel, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        const Spacer(),
        IconButton(onPressed: onLogout, icon: const Icon(Icons.logout, color: Colors.redAccent)),
      ],
    ),
  );
}

Widget _buildInfoCard(String name, String address, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Row(
      children: [
        Icon(icon, color: Colors.blue, size: 40),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Text(address, style: const TextStyle(color: Colors.grey)),
        ]))
      ],
    ),
  );
}

Widget _buildActionCard(String title, String subtitle, IconData icon, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Row(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    ),
  );
}

Widget _buildEmptyCalendar() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
    child: Column(children: [
      const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 40),
      const SizedBox(height: 16),
      const Text('Calendario de actividades próximamente', style: TextStyle(color: Colors.grey)),
    ]),
  );
}
