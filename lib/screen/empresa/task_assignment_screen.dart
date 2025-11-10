import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/company_database.dart';
import 'package:reciclaje_app/database/employee_database.dart';
import 'package:reciclaje_app/database/task_database.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/employee.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/task.dart';
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/services/recycling_data.dart';
import 'package:reciclaje_app/utils/category_utils.dart';

class TaskAssignmentScreen extends StatefulWidget {
  const TaskAssignmentScreen({super.key});

  @override
  State<TaskAssignmentScreen> createState() => _TaskAssignmentScreenState();
}

class _TaskAssignmentScreenState extends State<TaskAssignmentScreen> {
  // Services
  final _authService = AuthService();
  final _companyDatabase = CompanyDatabase();
  final _employeeDatabase = EmployeeDatabase();
  final _taskDatabase = TaskDatabase();
  final _usersDatabase = UsersDatabase();
  final _dataService = RecyclingDataService();
  
  // Controllers
  final _mapController = MapController();
  
  // State
  List<RecyclingItem> _allArticles = [];
  List<RecyclingItem> _availableArticles = []; // Articles without tasks
  List<Employee> _employees = [];
  List<Task> _existingTasks = [];
  int? _companyId;
  int? _currentUserId;
  bool _isLoading = true;
  String _filterStatus = 'available'; // 'available', 'assigned', 'all'
  
  // Selection state
  RecyclingItem? _selectedArticle;
  Employee? _selectedEmployee;
  String _selectedPriority = 'media';
  DateTime? _selectedDueDate;
  final TextEditingController _notesController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    
    try {
      // Get current user
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        final userData = await _usersDatabase.getUserByEmail(email);
        _currentUserId = userData?.id;
        
        // Get company by admin user ID
        if (_currentUserId != null) {
          final companies = await _companyDatabase.stream.first;
          final company = companies.firstWhere(
            (c) => c.adminUserId == _currentUserId,
            orElse: () => throw Exception('No company found'),
          );
          
          _companyId = company.companyId;
          
          // Load data
          await Future.wait([
            _loadArticles(),
            _loadEmployees(),
            _loadTasks(),
          ]);
        }
      }
    } catch (e) {
      print('❌ Error initializing: $e');
    }
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _loadArticles() async {
    final articles = await _dataService.loadRecyclingItems();
    setState(() {
      _allArticles = articles;
      _updateAvailableArticles();
    });
  }
  
  Future<void> _loadEmployees() async {
    if (_companyId == null) return;
    
    final employeesStream = _employeeDatabase.getEmployeesByCompany(_companyId!);
    final employeesList = await employeesStream.first;
    
    // Convert Map to Employee objects
    final employees = employeesList
        .map((map) => Employee.fromMap(map))
        .toList();
    
    setState(() => _employees = employees);
  }
  
  Future<void> _loadTasks() async {
    if (_companyId == null) return;
    
    // Use stream to get all tasks, then filter by companyId
    final allTasks = await _taskDatabase.stream.first;
    final companyTasks = allTasks.where((task) => task.companyId == _companyId).toList();
    
    setState(() {
      _existingTasks = companyTasks;
      _updateAvailableArticles();
    });
  }
  
  void _updateAvailableArticles() {
    final assignedArticleIds = _existingTasks
        .where((task) => task.workflowStatus != 'cancelado' && task.workflowStatus != 'completado')
        .map((task) => task.articleId)
        .toSet();
    
    setState(() {
      _availableArticles = _allArticles
          .where((article) => !assignedArticleIds.contains(article.id))
          .toList();
    });
  }
  
  List<RecyclingItem> get _filteredArticles {
    switch (_filterStatus) {
      case 'available':
        return _availableArticles;
      case 'assigned':
        final assignedIds = _existingTasks
            .where((task) => task.workflowStatus != 'cancelado' && task.workflowStatus != 'completado')
            .map((task) => task.articleId)
            .toSet();
        return _allArticles.where((a) => assignedIds.contains(a.id)).toList();
      default:
        return _allArticles;
    }
  }
  
  Future<void> _assignTask() async {
    if (_selectedArticle == null || _selectedEmployee == null || _companyId == null || _currentUserId == null) {
      _showSnackBar('Por favor seleccione un artículo y un empleado', isError: true);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final task = Task(
        employeeId: _selectedEmployee!.idEmployee,
        articleId: _selectedArticle!.id,
        companyId: _companyId,
        assignedDate: DateTime.now(),
        workflowStatus: 'asignado',
        state: 1,
        lastUpdate: DateTime.now(),
      );
      
      await _taskDatabase.createTask(task);
      
      _showSnackBar('✅ Tarea asignada exitosamente');
      
      // Reset selection
      setState(() {
        _selectedArticle = null;
        _selectedEmployee = null;
        _notesController.clear();
        _selectedDueDate = null;
        _selectedPriority = 'media';
      });
      
      // Reload data
      await _loadTasks();
    } catch (e) {
      print('❌ Error assigning task: $e');
      _showSnackBar('❌ Error al asignar la tarea: $e', isError: true);
    }
    
    setState(() => _isLoading = false);
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asignar Tareas a Empleados'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterChips(),
                _buildStatsBar(),
                Expanded(
                  child: Row(
                    children: [
                      // Map view
                      Expanded(
                        flex: 3,
                        child: _buildMapView(),
                      ),
                      // Assignment panel
                      Container(
                        width: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(-2, 0),
                            ),
                          ],
                        ),
                        child: _buildAssignmentPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
  
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Row(
        children: [
          const Text('Filtrar: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _buildFilterChip('Disponibles', 'available'),
          const SizedBox(width: 8),
          _buildFilterChip('Asignados', 'assigned'),
          const SizedBox(width: 8),
          _buildFilterChip('Todos', 'all'),
        ],
      ),
    );
  }
  
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[700],
    );
  }
  
  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('Artículos Disponibles', _availableArticles.length, Colors.blue),
          _buildStatCard('Empleados Activos', _employees.length, Colors.orange),
          _buildStatCard('Tareas Asignadas', _existingTasks.where((t) => t.workflowStatus == 'asignado').length, Colors.purple),
          _buildStatCard('En Proceso', _existingTasks.where((t) => t.workflowStatus == 'en_proceso').length, Colors.amber),
          _buildStatCard('Completadas', _existingTasks.where((t) => t.workflowStatus == 'completado').length, Colors.green),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
  
  Widget _buildMapView() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _filteredArticles.isNotEmpty
            ? LatLng(_filteredArticles.first.latitude, _filteredArticles.first.longitude)
            : const LatLng(-17.8146, -63.1561), // Santa Cruz, Bolivia
        initialZoom: 13.0,
        minZoom: 5.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.reciclaje_app',
        ),
        MarkerLayer(
          markers: _filteredArticles.map((article) {
            final isSelected = _selectedArticle?.id == article.id;
            final isAssigned = _existingTasks.any((task) => 
              task.articleId == article.id && 
              task.workflowStatus != 'cancelado' && 
              task.workflowStatus != 'completado'
            );
            
            return Marker(
              point: LatLng(article.latitude, article.longitude),
              width: isSelected ? 60 : 50,
              height: isSelected ? 60 : 50,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedArticle = article;
                    _mapController.move(
                      LatLng(article.latitude, article.longitude),
                      15.0,
                    );
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isAssigned ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.white,
                      width: isSelected ? 4 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    CategoryUtils.getCategoryIcon(article.categoryName),
                    color: Colors.white,
                    size: isSelected ? 30 : 24,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
  
  Widget _buildAssignmentPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nueva Asignación',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Selected Article
          _buildSelectedArticleCard(),
          const SizedBox(height: 20),
          
          // Employee Selection
          const Text('Seleccionar Empleado', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildEmployeeSelector(),
          const SizedBox(height: 20),
          
          // Priority
          const Text('Prioridad', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildPrioritySelector(),
          const SizedBox(height: 20),
          
          // Due Date
          const Text('Fecha Límite (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildDueDatePicker(),
          const SizedBox(height: 20),
          
          // Notes
          const Text('Notas para el Empleado', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: Recolectar antes del mediodía, material frágil...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          
          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedArticle != null && _selectedEmployee != null
                  ? _assignTask
                  : null,
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Asignar Tarea'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSelectedArticleCard() {
    if (_selectedArticle == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text(
            'Seleccione un artículo en el mapa',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  CategoryUtils.getCategoryIcon(_selectedArticle!.categoryName),
                  color: Colors.green[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedArticle!.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Categoría: ${_selectedArticle!.categoryName}'),
            Text('Ubicación: ${_selectedArticle!.address}'),
            if (_selectedArticle!.description != null)
              Text('Descripción: ${_selectedArticle!.description}'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildEmployeeSelector() {
    if (_employees.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: const Text('No hay empleados disponibles'),
      );
    }
    
    return DropdownButtonFormField<Employee>(
      value: _selectedEmployee,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Seleccione un empleado',
      ),
      items: _employees.map((employee) {
        return DropdownMenuItem(
          value: employee,
          child: FutureBuilder<Users?>(
            future: _usersDatabase.getUserById(employee.userId!),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final userName = snapshot.data!.names ?? 'Empleado ${employee.idEmployee}';
                return Text(userName);
              }
              return Text('Empleado ${employee.idEmployee}');
            },
          ),
        );
      }).toList(),
      onChanged: (employee) {
        setState(() => _selectedEmployee = employee);
      },
    );
  }
  
  Widget _buildPrioritySelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'baja', label: Text('Baja'), icon: Icon(Icons.arrow_downward)),
        ButtonSegment(value: 'media', label: Text('Media'), icon: Icon(Icons.remove)),
        ButtonSegment(value: 'alta', label: Text('Alta'), icon: Icon(Icons.arrow_upward)),
        ButtonSegment(value: 'urgente', label: Text('Urgente'), icon: Icon(Icons.warning)),
      ],
      selected: {_selectedPriority},
      onSelectionChanged: (Set<String> newSelection) {
        setState(() => _selectedPriority = newSelection.first);
      },
    );
  }
  
  Widget _buildDueDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDueDate ?? DateTime.now().add(const Duration(days: 3)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (date != null) {
          setState(() => _selectedDueDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDueDate != null
                  ? '${_selectedDueDate!.day}/${_selectedDueDate!.month}/${_selectedDueDate!.year}'
                  : 'Seleccionar fecha',
              style: TextStyle(
                color: _selectedDueDate != null ? Colors.black : Colors.grey,
              ),
            ),
            const Icon(Icons.calendar_today),
          ],
        ),
      ),
    );
  }
}
