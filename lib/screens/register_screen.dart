import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../api/api_service.dart';
import '../widgets/cow_background.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _apiService = ApiService();
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers
  final _namesController = TextEditingController();
  final _lastNamesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _fincaNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Selections & Data
  int? _selectedDocTypeId = 1;
  int _selectedRoleId = 3; 
  int? _selectedDeptId;
  int? _selectedMunId;
  int? _selectedAcopioId;
  double? _latitude;
  double? _longitude;

  List<dynamic> _departments = [];
  List<dynamic> _municipalities = [];
  List<dynamic> _centrosAcopio = [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadCentrosAcopio();
    
    // Listeners for real-time validation
    _namesController.addListener(_updateState);
    _lastNamesController.addListener(_updateState);
    _phoneController.addListener(_updateState);
    _emailController.addListener(_updateState);
    _idNumberController.addListener(_updateState);
    _fincaNameController.addListener(_updateState);
    _addressController.addListener(_updateState);
    _passwordController.addListener(_updateState);
    _confirmPasswordController.addListener(_updateState);
  }

  void _updateState() => setState(() {});

  Future<void> _loadDepartments() async {
    try {
      final response = await _apiService.getEntity('departamentos');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _departments = data['response'] ?? data;
        });
      }
    } catch (e) {
      print('Error loading departments: $e');
    }
  }

  Future<void> _loadMunicipalities(int deptId) async {
    try {
      final response = await _apiService.getEntity('municipios');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> allMun = data['response'] ?? data;
        setState(() {
          _municipalities = allMun.where((m) => m['departamentoId'] == deptId).toList();
          _selectedMunId = null;
        });
      }
    } catch (e) {
      print('Error loading municipalities: $e');
    }
  }

  Future<void> _loadCentrosAcopio() async {
    try {
      final response = await _apiService.getEntity('centros-acopio');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _centrosAcopio = data['response'] ?? data;
        });
      }
    } catch (e) {
      print('Error loading centros de acopio: $e');
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _latitude = position.latitude;
      _longitude = position.longitude;
    });
  }

  bool _isStepValid() {
    switch (_currentStep) {
      case 0:
        return _namesController.text.isNotEmpty && _lastNamesController.text.isNotEmpty && _phoneController.text.isNotEmpty;
      case 1:
        return _emailController.text.isNotEmpty && _idNumberController.text.isNotEmpty && _selectedDocTypeId != null;
      case 2:
        if (_selectedRoleId == 4) {
          // Worker flow: Centro acopio + Password
          return _selectedAcopioId != null && 
                 _passwordController.text.isNotEmpty && 
                 _confirmPasswordController.text.isNotEmpty && 
                 _passwordController.text == _confirmPasswordController.text;
        }
        return _fincaNameController.text.isNotEmpty && _selectedDeptId != null && _selectedMunId != null;
      case 3:
        return _addressController.text.isNotEmpty && _latitude != null && _longitude != null;
      case 4:
        return _passwordController.text.isNotEmpty && 
               _confirmPasswordController.text.isNotEmpty && 
               _passwordController.text == _confirmPasswordController.text;
      default:
        return false;
    }
  }

  void _nextStep() {
    int maxSteps = _selectedRoleId == 4 ? 2 : 4;
    if (_currentStep < maxSteps) {
      setState(() => _currentStep++);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _register();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(_currentStep, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  void _register() async {
    setState(() => _isLoading = true);
    
    final Map<String, dynamic> userData = {
      "email": _emailController.text,
      "password": _passwordController.text,
      "estado": "activo",
      "rolId": _selectedRoleId,
      "centroAcopioId": _selectedAcopioId,
    };

    if (_selectedRoleId == 3) {
      userData["productor"] = {
        "nombre": "${_namesController.text} ${_lastNamesController.text}",
        "documento": _idNumberController.text,
        "telefono": _phoneController.text,
        "tipoDocumentoId": _selectedDocTypeId,
        "fincaInicial": {
          "nombre": _fincaNameController.text,
          "direccion": _addressController.text,
          "latitud": _latitude,
          "longitud": _longitude,
          "municipioId": _selectedMunId
        }
      };
    } else if (_selectedRoleId == 2) {
      userData["centroAcopio"] = {
        "nombre": _fincaNameController.text,
        "direccion": _addressController.text,
        "latitud": _latitude,
        "longitud": _longitude,
        "municipioId": _selectedMunId
      };
    } else if (_selectedRoleId == 4) {
      userData["trabajador"] = {
        "nombre": "${_namesController.text} ${_lastNamesController.text}",
        "documento": _idNumberController.text,
        "telefono": _phoneController.text,
        "tipoDocumentoId": _selectedDocTypeId
      };
    }

    try {
      final response = await _apiService.register(userData);
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) _showSuccessDialog();
      } else {
        String errorMessage = responseData['response']?['message'] ?? responseData['errors']?.toString() ?? 'Error en el registro';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Text('🐮', style: TextStyle(fontSize: 40)), 
            ),
            const SizedBox(height: 20),
            const Text('Registro exitoso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Tu cuenta ha sido creada correctamente. Ahora puedes iniciar sesión.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CowBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 10),
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _prevStep),
              ),
            ),
            _buildStepIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  if (_selectedRoleId != 4) ...[
                    _buildStep3(),
                    _buildStep4(),
                    _buildStep5(),
                  ] else ...[
                    _buildWorkerStep(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    int totalSteps = _selectedRoleId == 4 ? 3 : 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == _currentStep ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == _currentStep ? Colors.grey[800] : Colors.grey[400],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStep1() {
    return _buildContainer([
      _buildTextField(_namesController, 'Nombres', Icons.person_outline),
      const SizedBox(height: 15),
      _buildTextField(_lastNamesController, 'Apellidos', Icons.person_outline),
      const SizedBox(height: 15),
      _buildTextField(_phoneController, 'Número de teléfono', Icons.phone_android_outlined),
      const SizedBox(height: 25),
      Align(alignment: Alignment.centerRight, child: _buildNextButton()),
      const SizedBox(height: 20),
      const Divider(),
      const Center(child: Text('O registrate con:', style: TextStyle(color: Colors.grey))),
      const SizedBox(height: 10),
      const Center(child: CircleAvatar(radius: 20, backgroundColor: Colors.grey, child: Text('G', style: TextStyle(color: Colors.white)))),
    ]);
  }

  Widget _buildStep2() {
    return _buildContainer([
      _buildTextField(_emailController, 'Correo electrónico', Icons.mail_outline),
      const SizedBox(height: 15),
      _buildDocDropdown(),
      const SizedBox(height: 15),
      _buildTextField(_idNumberController, 'Número de identificación', Icons.badge_outlined),
      const SizedBox(height: 20),
      const Align(alignment: Alignment.centerLeft, child: Text('Tipo de registro:', style: TextStyle(fontWeight: FontWeight.bold))),
      _buildRoleOption('Productor', Icons.eco_outlined, 3),
      _buildRoleOption('Centro de acopio', Icons.business_outlined, 2),
      _buildRoleOption('Trabajador', Icons.build_outlined, 4),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildBackButton(), _buildNextButton()])
    ]);
  }

  Widget _buildStep3() {
    String title = _selectedRoleId == 2 ? 'Centro de acopio' : 'Información de la finca';
    String hint = _selectedRoleId == 2 ? 'Nombre del centro de acopio' : 'Nombre de la finca';
    IconData icon = _selectedRoleId == 2 ? Icons.business_outlined : Icons.eco_outlined;

    return _buildContainer([
      Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const SizedBox(height: 20),
      _buildTextField(_fincaNameController, hint, icon),
      const SizedBox(height: 15),
      _buildDeptDropdown(),
      const SizedBox(height: 15),
      _buildMunDropdown(),
      const SizedBox(height: 30),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildBackButton(), _buildNextButton()])
    ]);
  }

  Widget _buildStep4() {
    return _buildContainer([
      const Align(alignment: Alignment.centerLeft, child: Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const SizedBox(height: 20),
      _buildTextField(_addressController, 'Dirección (Ej: Cra 1N#20)', Icons.home_outlined),
      const SizedBox(height: 15),
      ElevatedButton.icon(
        onPressed: _getLocation,
        icon: const Icon(Icons.my_location),
        label: const Text('Obtener ubicación'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey[300],
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      if (_latitude != null) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 5),
            Text('Lat: ${_latitude!.toStringAsFixed(4)}, Lng: ${_longitude!.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
      const SizedBox(height: 30),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildBackButton(), _buildNextButton()])
    ]);
  }

  Widget _buildStep5() {
    return _buildContainer([
      const Align(alignment: Alignment.centerLeft, child: Text('Crea tu contraseña', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const SizedBox(height: 20),
      _buildTextField(_passwordController, 'Contraseña', Icons.lock_outline, obscure: true),
      const SizedBox(height: 15),
      _buildTextField(_confirmPasswordController, 'Confirmar contraseña', Icons.lock_outline, obscure: true),
      const SizedBox(height: 30),
      _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildBackButton(), _buildNextButton(label: 'REGISTRARSE')])
    ]);
  }

  Widget _buildWorkerStep() {
    return _buildContainer([
      const Align(alignment: Alignment.centerLeft, child: Text('Centro de acopio y acceso', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
      const SizedBox(height: 20),
      _buildAcopioDropdown(),
      const SizedBox(height: 15),
      _buildTextField(_passwordController, 'Contraseña', Icons.lock_outline, obscure: true),
      const SizedBox(height: 15),
      _buildTextField(_confirmPasswordController, 'Confirmar contraseña', Icons.lock_outline, obscure: true),
      const SizedBox(height: 30),
      _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildBackButton(), _buildNextButton(label: 'REGISTRARSE')])
    ]);
  }

  Widget _buildContainer(List<Widget> children) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey),
        hintText: hint,
        filled: true,
        fillColor: Colors.grey[200],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        suffixIcon: obscure ? const Icon(Icons.visibility_outlined, color: Colors.grey) : null,
      ),
    );
  }

  Widget _buildDocDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDocTypeId,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 1, child: Row(children: [Icon(Icons.badge_outlined, color: Colors.grey), SizedBox(width: 10), Text('Cédula')])),
            DropdownMenuItem(value: 2, child: Row(children: [Icon(Icons.badge_outlined, color: Colors.grey), SizedBox(width: 10), Text('Tarjeta ID')])),
          ],
          onChanged: (v) => setState(() => _selectedDocTypeId = v!),
        ),
      ),
    );
  }

  Widget _buildDeptDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedDeptId,
          isExpanded: true,
          hint: Row(children: const [Icon(Icons.map_outlined, color: Colors.grey), SizedBox(width: 10), Text('Departamento', style: TextStyle(color: Colors.black54))]),
          items: _departments.map((d) => DropdownMenuItem<int>(value: d['departamentoId'], child: Text(d['nombre']))).toList(),
          onChanged: (v) {
            setState(() {
              _selectedDeptId = v;
              _selectedMunId = null;
              _municipalities = [];
            });
            if (v != null) _loadMunicipalities(v);
          },
        ),
      ),
    );
  }

  Widget _buildMunDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedMunId,
          isExpanded: true,
          hint: Row(children: const [Icon(Icons.location_on_outlined, color: Colors.grey), SizedBox(width: 10), Text('Municipio', style: TextStyle(color: Colors.black54))]),
          items: _municipalities.map((m) => DropdownMenuItem<int>(value: m['municipioId'], child: Text(m['nombre']))).toList(),
          onChanged: (v) => setState(() => _selectedMunId = v),
        ),
      ),
    );
  }

  Widget _buildAcopioDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedAcopioId,
          isExpanded: true,
          hint: Row(children: const [Icon(Icons.business, color: Colors.grey), SizedBox(width: 10), Text('Centro de acopio', style: TextStyle(color: Colors.black54))]),
          items: _centrosAcopio.map((c) => DropdownMenuItem<int>(value: c['centroAcopioId'], child: Text(c['nombre']))).toList(),
          onChanged: (v) => setState(() => _selectedAcopioId = v),
        ),
      ),
    );
  }

  Widget _buildRoleOption(String label, IconData icon, int roleId) {
    bool isSelected = _selectedRoleId == roleId;
    return InkWell(
      onTap: () => setState(() {
        _selectedRoleId = roleId;
        _currentStep = 1; // Reseteamos al paso 1 para recalcular el PageView
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 10),
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 10),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton({String label = 'Siguiente'}) {
    bool isValid = _isStepValid();
    return ElevatedButton(
      onPressed: isValid ? _nextStep : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: isValid ? Colors.grey[300] : Colors.grey[200],
        foregroundColor: isValid ? Colors.black : Colors.grey,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Text(label), const SizedBox(width: 5), const Icon(Icons.arrow_forward, size: 16)]),
    );
  }

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: _prevStep,
      icon: const Icon(Icons.arrow_back, size: 16, color: Colors.black),
      label: const Text('Anterior', style: TextStyle(color: Colors.black)),
    );
  }

  @override
  void dispose() {
    _namesController.dispose();
    _lastNamesController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _idNumberController.dispose();
    _fincaNameController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
