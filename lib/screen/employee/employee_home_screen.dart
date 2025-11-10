import 'package:flutter/material.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/database/users_database.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/screen/distribuidor/detail_recycle_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final AuthService _authService = AuthService();
  final UsersDatabase _usersDb = UsersDatabase();
  
  String? _employeeName;
  int? _employeeId;
  bool _isLoading = true;
  int _pendingTasksCount = 0;
  int _completedTasksCount = 0;
  List<Map<String, dynamic>> _todayTasks = [];

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
  }

  Future<void> _loadEmployeeData() async {
    try {
      final email = _authService.getCurrentUserEmail();
      if (email != null) {
        final user = await _usersDb.getUserByEmail(email);
        if (user != null) {
          // Get employee ID
          final employeeData = await Supabase.instance.client
              .from('employees')
              .select('idEmployee')
              .eq('userID', user.id!)
              .maybeSingle();

          if (mounted && employeeData != null) {
            setState(() {
              _employeeName = user.names;
              _employeeId = employeeData['idEmployee'] as int;
            });
            
            // Load tasks after getting employee ID
            await _loadTasks();
          }
        }
      }
    } catch (e) {
      print('Error loading employee data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTasks() async {
    if (_employeeId == null) return;

    try {
      // Get all tasks for this employee with article details
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('''
            idTask,
            employeeID,
            articleID,
            companyID,
            requestID,
            assignedDate,
            workflowStatus,
            state,
            lastUpdate,
            article:articleID(
              idArticle,
              name,
              description,
              address,
              lat,
              lng,
              categoryID,
              userID,
              availableDays,
              availableTimeStart,
              availableTimeEnd,
              condition,
              lastUpdate,
              category:categoryID(name),
              user:userID(names, email)
            ),
            request:requestID(
              scheduledDay,
              scheduledTime
            )
          ''')
          .eq('employeeID', _employeeId!)
          .order('assignedDate', ascending: false);

      if (mounted) {
        final taskList = List<Map<String, dynamic>>.from(tasks);
        
        // Count pending and completed
        final pending = taskList.where((t) => 
            t['workflowStatus'] == 'asignado' || t['workflowStatus'] == 'en_proceso'
        ).length;
        
        final completed = taskList.where((t) => 
            t['workflowStatus'] == 'completado'
        ).length;

        // Get today's tasks (assigned or in progress)
        final today = taskList.where((t) => 
            (t['workflowStatus'] == 'asignado' || t['workflowStatus'] == 'en_proceso')
        ).toList();

        setState(() {
          _pendingTasksCount = pending;
          _completedTasksCount = completed;
          _todayTasks = today;
          _isLoading = false;
        });

        print('✅ Loaded ${taskList.length} tasks for employee $_employeeId');
      }
    } catch (e) {
      print('❌ Error loading tasks: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${_employeeName ?? 'Empleado'}! 👋',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bienvenido a tu panel',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFF2D8A8A),
                    child: Text(
                      _employeeName?.substring(0, 1).toUpperCase() ?? 'E',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Quick Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.task_alt,
                      label: 'Tareas Pendientes',
                      value: '$_pendingTasksCount',
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle,
                      label: 'Completadas',
                      value: '$_completedTasksCount',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // Today's Tasks Section
              const Text(
                'Tareas de Hoy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 16),
              
              // Tasks list or empty state
              if (_todayTasks.isEmpty)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay tareas asignadas',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las tareas aparecerán aquí cuando se te asignen',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                ..._todayTasks.map((task) => _buildTaskCard(task)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final article = task['article'] as Map<String, dynamic>?;
    final request = task['request'] as Map<String, dynamic>?;
    final category = article?['category'] as Map<String, dynamic>?;
    final user = article?['user'] as Map<String, dynamic>?;
    
    final title = article?['name'] ?? 'Sin título';
    final address = article?['address'] ?? 'Sin dirección';
    final status = task['workflowStatus'] as String;
    final scheduledDay = request?['scheduledDay'] ?? 'No especificado';
    final scheduledTime = request?['scheduledTime'] ?? 'No especificado';
    
    Color statusColor = Colors.orange;
    String statusText = 'Asignado';
    IconData statusIcon = Icons.pending;
    
    if (status == 'en_proceso') {
      statusColor = Colors.blue;
      statusText = 'En Proceso';
      statusIcon = Icons.play_circle;
    } else if (status == 'completado') {
      statusColor = Colors.green;
      statusText = 'Completado';
      statusIcon = Icons.check_circle;
    }

    // Create RecyclingItem for navigation
    RecyclingItem? recyclingItem;
    if (article != null) {
      recyclingItem = RecyclingItem(
        id: article['idArticle'] as int,
        title: article['name'] as String,
        description: article['description'] as String?,
        address: article['address'] as String,
        latitude: (article['lat'] as num).toDouble(),
        longitude: (article['lng'] as num).toDouble(),
        categoryID: article['categoryID'] as int?,
        categoryName: category?['name'] as String? ?? 'Sin categoría',
        ownerUserId: article['userID'] as int?,
        userName: user?['names'] as String? ?? 'Usuario',
        userEmail: user?['email'] as String? ?? '',
        availableDays: article['availableDays'] as String? ?? 'No especificado',
        availableTimeStart: article['availableTimeStart'] as String? ?? '00:00',
        availableTimeEnd: article['availableTimeEnd'] as String? ?? '23:59',
        condition: article['condition'] as String?,
        workflowStatus: article['workflowStatus'] as String?,
        createdAt: DateTime.now(), // Use current time as fallback
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: recyclingItem != null
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailRecycleScreen(item: recyclingItem!),
                  ),
                )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D8A8A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        category['name'] ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '$scheduledDay a las $scheduledTime',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (status == 'asignado')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Start task
                        },
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Iniciar Tarea'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (status == 'asignado') const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: recyclingItem != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailRecycleScreen(item: recyclingItem!),
                                ),
                              )
                          : null,
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Ver Detalles'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2D8A8A),
                        side: const BorderSide(color: Color(0xFF2D8A8A)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
