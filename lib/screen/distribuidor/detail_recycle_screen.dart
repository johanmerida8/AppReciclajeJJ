import 'dart:async';
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:reciclaje_app/auth/auth_service.dart';
import 'package:reciclaje_app/components/availability_data.dart';
import 'package:reciclaje_app/components/condition_selector.dart';
import 'package:reciclaje_app/components/location_map_preview.dart';
import 'package:reciclaje_app/components/photo_gallery_widget.dart';
import 'package:reciclaje_app/components/photo_validation.dart';
import 'package:reciclaje_app/components/schedule_pickup_dialog.dart'; // ✅ Add import
import 'package:reciclaje_app/model/users.dart';
import 'package:reciclaje_app/utils/Fixed43Cropper.dart';
// import 'package:reciclaje_app/components/row_button_2.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/database/request_database.dart'; // ✅ Add request database
import 'package:reciclaje_app/database/users_database.dart'; // ✅ Add users database
import 'package:reciclaje_app/database/task_database.dart'; // ✅ Add task database
import 'package:reciclaje_app/database/userPointsLog_database.dart'; // ✅ Add points log database
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/model/recycling_items.dart';
import 'package:reciclaje_app/model/request.dart'; // ✅ Add request model
import 'package:reciclaje_app/model/task.dart'; // ✅ Add task model
import 'package:reciclaje_app/model/userPointsLog.dart'; // ✅ Add points log model
// import 'package:reciclaje_app/screen/home_screen.dart';
import 'package:reciclaje_app/components/my_button.dart';
import 'package:reciclaje_app/components/category_tags.dart';
import 'package:reciclaje_app/components/my_textformfield.dart';
import 'package:reciclaje_app/components/limit_character_two.dart';
import 'package:reciclaje_app/database/article_database.dart';
import 'package:reciclaje_app/database/category_database.dart';
import 'package:reciclaje_app/database/days_available_database.dart';
// import 'package:reciclaje_app/database/deliver_database.dart';
import 'package:reciclaje_app/model/article.dart';
import 'package:reciclaje_app/model/category.dart';
import 'package:reciclaje_app/model/daysAvailable.dart';
// import 'package:reciclaje_app/model/deliver.dart';
import 'package:reciclaje_app/screen/distribuidor/navigation_screens.dart';
import 'package:reciclaje_app/screen/employee/employee_navigation_screens.dart';
import 'package:reciclaje_app/services/workflow_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailRecycleScreen extends StatefulWidget {
  final RecyclingItem item;
  final bool
  isEmpresaView; // ✅ Flag to indicate empresa view (read-only, reviews only)
  final Map<String, dynamic>?
  taskData; // ✅ Optional task data with reviews and schedule

  const DetailRecycleScreen({
    super.key,
    required this.item,
    this.isEmpresaView = false, // Default to false (normal admin view)
    this.taskData, // Optional task data for empresa view
  });

  @override
  State<DetailRecycleScreen> createState() => _DetailRecycleScreenState();
}

class _DetailRecycleScreenState extends State<DetailRecycleScreen> {
  // final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final articleDatabase = ArticleDatabase();
  final categoryDatabase = CategoryDatabase();
  final daysAvailableDatabase = DaysAvailableDatabase();
  // final deliverDatabase = DeliverDatabase();
  final mediaDatabase = MediaDatabase();
  final workflowService = WorkflowService();
  final requestDatabase = RequestDatabase(); // ✅ Add request database
  final usersDatabase = UsersDatabase(); // ✅ Add users database
  final taskDatabase = TaskDatabase(); // ✅ Add task database
  final pointsLogDatabase =
      UserpointslogDatabase(); // ✅ Add points log database

  final _authService = AuthService();
  Users? currentUser;
  Multimedia? currentUserAvatar;

  String? _currentUserEmail;
  String? _currentUserRole; // ✅ Track user role
  int? _currentUserId; // ✅ Track user ID
  int? _companyId; // ✅ Track company ID for admin-empresa
  Request? _existingRequest; // ✅ Track request status for this article
  bool isLoading = true;
  bool _isLoadingRequest = false; // ✅ Loading request status
  List<Map<String, dynamic>> _employees =
      []; // ✅ Add employees list for company
  Set<int> _assignedEmployeeIds = {}; // ✅ Track employees with active tasks

  // ✅ Employee task tracking
  String? _employeeScheduledDay;
  String? _employeeScheduledTime;
  int? _employeeTaskId; // Track task ID for updates
  String? _employeeTaskStatus; // Track task workflow status

  // ✅ Distributor task tracking (for article owner)
  int? _distributorTaskId; // Track task ID for distributor
  String? _distributorTaskStatus; // Track distributor's task workflow status
  int?
  _distributorEmployeeId; // Track which employee is assigned (employeeID from employees table)
  int?
  _distributorEmployeeUserId; // Track employee's userID for review (userID from users table)
  String? _distributorScheduledDay; // Track scheduled day for distributor
  String? _distributorScheduledTime; // Track scheduled time for distributor

  // ✅ Company task tracking (for company admin viewing their requests)
  int? _companyTaskId; // Track task ID for company
  String?
  _companyTaskStatus; // Track company's task workflow status (en_proceso, completado, etc.)
  Map<String, dynamic>?
  _companyTaskData; // Store full task data including reviews
  String? _companyScheduledDay; // Track scheduled day for company
  String? _companyScheduledTime; // Track scheduled time for company

  // ✅ Real-time subscription for task updates
  RealtimeChannel? _taskSubscription;

  List<Category> _categories = [];
  List<Multimedia> _photos = [];
  List<Multimedia> _photosToDelete = [];
  List<XFile> pickedImages = [];
  List<Map<String, dynamic>> _pendingRequests =
      []; // ✅ Add pending requests list
  bool _hasApprovedRequests = false; // ✅ Track if article has approved requests

  Multimedia? _mainPhoto;
  bool _isLoadingPhotos = true;

  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;

  Category? _selectedCategory;
  String? _selectedCondition;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isEditing = false;
  Set<int> _disabledCategoryIds = {};

  // Location variables
  LatLng? _selectedLocation;
  String? _selectedAddress;

  // Availability
  AvailabilityData? _selectedAvailability;

  // Original data for comparison
  late String _originalTitle;
  late String _originalDescription;
  late String _originalCategoryName;
  late String _originalConditionName;
  late String _originalAddress;
  late LatLng _originalLocation;
  AvailabilityData? _originalAvailability;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPhotos();
    _loadDisabledCategories();
    _loadAvailabilityData(); // ✅ Load availability from daysAvailable table
    _debugDatabaseStructure(); // ✅ Debug temporal

    _currentUserEmail = _authService.getCurrentUserEmail();
    _loadUserRoleAndRequest(); // ✅ Load user role and check for existing request
    _loadPendingRequests(); // ✅ Load pending requests for this article
    _checkApprovedRequests(); // ✅ Check for approved requests
    _loadEmployeeTask(); // ✅ Load employee's task if employee
    _loadDistributorTask(); // ✅ Load distributor's task if owner
    // ✅ _loadCompanyTask() is now called AFTER _loadUserRoleAndRequest() completes
    // ❌ DON'T load employees here - they need _companyId to be set first

    // Initialize basic data (non-async)
    _initializeBasicData();
  }

  // ✅ Método para refrescar categorías bloqueadas cuando se necesite
  Future<void> _refreshDisabledCategories() async {
    if (_isOwner) {
      await _loadDisabledCategories();
      print('🔄 Categorías bloqueadas refrescadas');
    }
  }

  // ✅ Método debug temporal para verificar la estructura de la DB
  Future<void> _debugDatabaseStructure() async {
    try {
      print('🔍 DEBUG: Verificando estructura de la tabla multimedia...');

      // Intentar obtener todas las fotos para debug
      final allPhotos = await Supabase.instance.client
          .from('multimedia')
          .select('*')
          .limit(5);

      print('📊 Total fotos en DB (muestra): ${allPhotos.length}');
      for (var photo in allPhotos) {
        print(
          '   - Foto: ${photo['fileName']} -> FilePath: ${photo['filePath']}',
        );
      }

      // Verificar específicamente para este artículo usando el patrón
      final articlePattern = 'articles/${widget.item.id}';
      final articlePhotos = await Supabase.instance.client
          .from('multimedia')
          .select('*')
          .like('filePath', '%$articlePattern%');

      print(
        '📸 Fotos para artículo ${widget.item.id}: ${articlePhotos.length}',
      );
      for (var photo in articlePhotos) {
        print('   - ${photo['fileName']} (isMain: ${photo['isMain']})');
      }
    } catch (e) {
      print('❌ Error en debug de estructura: $e');
    }
  }

  bool get _isOwner => widget.item.userEmail == _currentUserEmail;

  /// ✅ Check if current user is admin-empresa
  bool get _isCompanyAdmin =>
      _currentUserRole?.toLowerCase() == 'admin-empresa';

  /// ✅ Check if current user is employee
  bool get _isEmployee => _currentUserRole?.toLowerCase() == 'empleado';

  /// ✅ Load user role and check for existing request
  Future<void> _loadUserRoleAndRequest() async {
    if (_currentUserEmail == null) return;

    setState(() => _isLoadingRequest = true);

    try {
      // Get user info
      final user = await usersDatabase.getUserByEmail(_currentUserEmail!);

      if (user != null) {
        setState(() {
          _currentUserId = user.id;
          _currentUserRole = user.role;
        });

        // If user is admin-empresa, load company ID and check for existing request
        if (_isCompanyAdmin && _currentUserId != null) {
          // Try to get company ID from empresa table (if user is admin-empresa)
          var companyData =
              await Supabase.instance.client
                  .from('company')
                  .select('idCompany')
                  .eq('adminUserID', _currentUserId!)
                  .limit(1)
                  .maybeSingle();

          print('🔍 Company query result: $companyData');

          // If not found in empresa table, try employees table (if user is employee)
          if (companyData == null) {
            companyData =
                await Supabase.instance.client
                    .from('employees')
                    .select('companyID')
                    .eq('userID', _currentUserId!)
                    .limit(1)
                    .maybeSingle();

            print('🔍 Employee query result: $companyData');

            if (companyData != null) {
              _companyId = companyData['companyID'] as int?;
            }
          } else {
            _companyId = companyData['idCompany'] as int?;
          }

          print('🔍 Final company ID: $_companyId');

          // Check for existing request for this article
          if (_companyId != null) {
            final existingRequest =
                await Supabase.instance.client
                    .from('request')
                    .select()
                    .eq('articleID', widget.item.id)
                    .eq('companyID', _companyId!)
                    .order(
                      'lastUpdate',
                      ascending: false,
                    ) // Get most recent first
                    .limit(1)
                    .maybeSingle();

            if (existingRequest != null) {
              setState(() {
                _existingRequest = Request.fromMap(existingRequest);
              });
              print(
                '✅ Found existing request with status: ${_existingRequest!.status}',
              );
            } else {
              print('ℹ️ No existing request found for this article');
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error loading user role and request: $e');
    } finally {
      setState(() => _isLoadingRequest = false);

      // ✅ Load employees AFTER user role and company ID are set
      await _loadEmployees();

      // ✅ Load company task AFTER company ID is set (for admin-empresa)
      await _loadCompanyTask();
    }
  }

  /// ✅ Load pending requests for this article
  Future<void> _loadPendingRequests() async {
    if (!_isOwner) return; // Only owner can see requests

    try {
      final requests = await Supabase.instance.client
          .from('request')
          .select('''
            *,
            company:companyID (
              idCompany,
              nameCompany
            )
          ''')
          .eq('articleID', widget.item.id)
          .eq('status', 'pendiente')
          .order('requestDate', ascending: false);

      // Load company logos
      for (var request in requests) {
        final company = request['company'] as Map<String, dynamic>?;
        if (company != null) {
          final companyId = company['idCompany'];
          // Use only companyId pattern to avoid issues with special characters
          final logoPattern = 'empresa/$companyId/avatar/';
          final logo = await mediaDatabase.getMainPhotoByPattern(logoPattern);
          request['companyLogo'] = logo;
        }
      }

      setState(() {
        _pendingRequests = requests;
      });
    } catch (e) {
      print('❌ Error loading pending requests: $e');
    }
  }

  /// ✅ Check if there are any approved requests for this article
  Future<void> _checkApprovedRequests() async {
    if (!_isOwner) return; // Only check for article owner

    try {
      final approvedRequests = await Supabase.instance.client
          .from('request')
          .select('idRequest')
          .eq('articleID', widget.item.id)
          .eq('status', 'aprobado')
          .eq('state', 1);

      setState(() {
        _hasApprovedRequests = approvedRequests.isNotEmpty;
      });

      if (_hasApprovedRequests) {
        print(
          '⚠️ Found ${approvedRequests.length} approved request(s) - Edit/Delete disabled',
        );
      }
    } catch (e) {
      print('❌ Error checking approved requests: $e');
    }
  }

  /// ✅ Load employees for company (if admin-empresa)
  Future<void> _loadEmployees() async {
    if (!_isCompanyAdmin || _companyId == null) return;

    try {
      final employees = await Supabase.instance.client
          .from('employees')
          .select('employeeId:idEmployee, userID, users:userID(names, email)')
          .eq('companyID', _companyId!);

      if (mounted) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(employees);
        });
        print(
          '✅ Loaded ${_employees.length} employees for company $_companyId',
        );

        // Load assigned employees for this article
        await _loadAssignedEmployees();
      }
    } catch (e) {
      print('❌ Error loading employees: $e');
    }
  }

  /// ✅ Load employees who already have active tasks for this article
  Future<void> _loadAssignedEmployees() async {
    try {
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('employeeID')
          .eq('articleID', widget.item.id)
          .inFilter('workflowStatus', [
            'asignado',
            'en_proceso',
          ]); // Active tasks

      final assignedIds =
          tasks.map((task) => task['employeeID'] as int).toSet();

      if (mounted) {
        setState(() {
          _assignedEmployeeIds = assignedIds;
        });
        print(
          '✅ Found ${_assignedEmployeeIds.length} employees with active tasks for this article',
        );
      }
    } catch (e) {
      print('❌ Error loading assigned employees: $e');
    }
  }

  /// ✅ Load employee's task to get scheduled day and time
  Future<void> _loadEmployeeTask() async {
    if (_currentUserEmail == null) return;

    try {
      // Get current user
      final user = await usersDatabase.getUserByEmail(_currentUserEmail!);
      if (user == null || user.role?.toLowerCase() != 'empleado') return;

      // Get employee ID
      final employeeData =
          await Supabase.instance.client
              .from('employees')
              .select('idEmployee')
              .eq('userID', user.id!)
              .maybeSingle();

      if (employeeData == null) return;

      final employeeId = employeeData['idEmployee'] as int;

      // Get task for this employee and article with request details
      final taskData =
          await Supabase.instance.client
              .from('tasks')
              .select('''
            *,
            request:requestID(
              scheduledDay,
              scheduledStartTime,
              scheduledEndTime
            )
          ''')
              .eq('employeeID', employeeId)
              .eq('articleID', widget.item.id)
              .eq('workflowStatus', 'en_proceso')
              .maybeSingle();

      if (taskData != null && mounted) {
        final request = taskData['request'] as Map<String, dynamic>?;
        setState(() {
          _employeeTaskId = taskData['idTask'] as int?;
          _employeeTaskStatus = taskData['workflowStatus'] as String?;
          _employeeScheduledDay = request?['scheduledDay'] as String?;
          _employeeScheduledTime = request?['scheduledStartTime'] as String?;
        });
        print(
          '✅ Loaded employee task (ID: $_employeeTaskId, Status: $_employeeTaskStatus) - Scheduled: $_employeeScheduledDay at $_employeeScheduledTime',
        );

        // ✅ Setup real-time listener for task status changes (for employee)
        _setupEmployeeTaskStatusListener();
      }
    } catch (e) {
      print('❌ Error loading employee task: $e');
    }
  }

  /// ✅ Setup real-time listener for employee task status changes
  void _setupEmployeeTaskStatusListener() {
    if (_employeeTaskId == null) return;

    // Subscribe to task updates
    _taskSubscription =
        Supabase.instance.client
            .channel('task_status_employee_$_employeeTaskId')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'tasks',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'idTask',
                value: _employeeTaskId,
              ),
              callback: (payload) {
                final newData = payload.newRecord;
                final newStatus = newData['workflowStatus'] as String?;

                print('🔔 Employee task status changed to: $newStatus');

                if (mounted && newStatus != _employeeTaskStatus) {
                  setState(() {
                    _employeeTaskStatus = newStatus;
                  });

                  // ✅ Show notification dialog when distributor confirms
                  if (newStatus == 'esperando_confirmacion_empleado') {
                    _showDistributorConfirmedNotification();
                  }
                }
              },
            )
            .subscribe();

    print('🔔 Real-time listener setup for employee task $_employeeTaskId');
  }

  /// ✅ Show notification when distributor confirms delivery
  void _showDistributorConfirmedNotification() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Distribuidor Confirmó',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El distribuidor ha confirmado que entregó el objeto:',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.item.title}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Deseas confirmar que recibiste el objeto?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Después'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showConfirmArrivalDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar Ahora'),
              ),
            ],
          ),
    );
  }

  /// ✅ Load distributor's task to check if they need to confirm delivery
  Future<void> _loadDistributorTask() async {
    if (!_isOwner) return; // Only load for article owner (distributor)

    try {
      // Query tasks table for this article where distributor needs to confirm delivery
      // ✅ Join with employees table to get the userID and request to get scheduled time
      final taskData =
          await Supabase.instance.client
              .from('tasks')
              .select('''
            idTask, 
            workflowStatus, 
            employeeID,
            employees:employeeID(userID),
            request:requestID(
              scheduledDay,
              scheduledStartTime,
              scheduledEndTime
            )
          ''')
              .eq('articleID', widget.item.id)
              .eq('state', 1)
              .maybeSingle();

      if (taskData != null) {
        final employeeData = taskData['employees'] as Map<String, dynamic>?;
        final request = taskData['request'] as Map<String, dynamic>?;

        setState(() {
          _distributorTaskId = taskData['idTask'] as int?;
          _distributorTaskStatus = taskData['workflowStatus'] as String?;
          _distributorEmployeeId = taskData['employeeID'] as int?;
          _distributorEmployeeUserId =
              employeeData?['userID'] as int?; // ✅ Get userID for review
          _distributorScheduledDay = request?['scheduledDay'] as String?;
          _distributorScheduledTime = request?['scheduledStartTime'] as String?;
        });

        print(
          '✅ Loaded distributor task (ID: $_distributorTaskId, Status: $_distributorTaskStatus, Employee UserID: $_distributorEmployeeUserId)',
        );

        // ✅ Setup real-time listener for task status changes
        _setupTaskStatusListener();
      } else {
        print('ℹ️ No active task found for distributor on this article');
      }
    } catch (e) {
      print('❌ Error loading distributor task: $e');
    }
  }

  /// ✅ Setup real-time listener for task status changes
  void _setupTaskStatusListener() {
    if (_distributorTaskId == null) return;

    // Subscribe to task updates
    _taskSubscription =
        Supabase.instance.client
            .channel('task_status_${_distributorTaskId}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'tasks',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'idTask',
                value: _distributorTaskId,
              ),
              callback: (payload) {
                final newData = payload.newRecord;
                final newStatus = newData['workflowStatus'] as String?;

                print('🔔 Task status changed to: $newStatus');

                if (mounted && newStatus != _distributorTaskStatus) {
                  setState(() {
                    _distributorTaskStatus = newStatus;
                  });

                  // ✅ Show notification dialog when employee confirms
                  if (newStatus == 'esperando_confirmacion_distribuidor') {
                    _showEmployeeConfirmedNotification();
                  }
                }
              },
            )
            .subscribe();

    print('🔔 Real-time listener setup for task $_distributorTaskId');
  }

  /// ✅ Load company admin's task to check status and show appropriate UI
  Future<void> _loadCompanyTask() async {
    if (_isOwner || !_isCompanyAdmin || _companyId == null) {
      print(
        'ℹ️ Skipping _loadCompanyTask: _isOwner=$_isOwner, _isCompanyAdmin=$_isCompanyAdmin, _companyId=$_companyId',
      );
      return; // Only for company admin viewing other's articles
    }

    try {
      print(
        '🔍 Loading company task for company $_companyId and article ${widget.item.id}',
      );

      // Get task for this article and company with request details
      // Note: Reviews are loaded separately via _loadReviews() since they reference articleID directly
      final taskData =
          await Supabase.instance.client
              .from('tasks')
              .select('''
            *,
            request:requestID(
              scheduledDay,
              scheduledStartTime,
              scheduledEndTime
            )
          ''')
              .eq('articleID', widget.item.id)
              .eq('companyID', _companyId!)
              .eq('state', 1)
              .maybeSingle();

      if (taskData != null && mounted) {
        final request = taskData['request'] as Map<String, dynamic>?;
        setState(() {
          _companyTaskId = taskData['idTask'] as int?;
          _companyTaskStatus = taskData['workflowStatus'] as String?;
          _companyTaskData = taskData;
          _companyScheduledDay = request?['scheduledDay'] as String?;
          _companyScheduledTime = request?['scheduledStartTime'] as String?;
        });
        print(
          '✅ Loaded company task (ID: $_companyTaskId, Status: $_companyTaskStatus, Scheduled: $_companyScheduledDay at $_companyScheduledTime)',
        );
      } else {
        print('ℹ️ No task found for company on this article');
      }
    } catch (e) {
      print('❌ Error loading company task: $e');
    }
  }

  /// ✅ Show notification when employee confirms arrival
  void _showEmployeeConfirmedNotification() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.notifications_active,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Empleado Confirmó',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El empleado ha confirmado que recibió el objeto:',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.item.title}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¿Deseas confirmar que entregaste el objeto?',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Después'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showConfirmDeliveryDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar Ahora'),
              ),
            ],
          ),
    );
  }

  /// ✅ Handle accept request - now with employee assignment option
  Future<void> _handleAcceptRequest(Map<String, dynamic> requestData) async {
    try {
      final requestId = requestData['idRequest'];
      final articleId = requestData['articleID'] ?? widget.item.id;
      final companyId = requestData['companyID'];

      if (companyId == null) {
        throw Exception('Missing company ID in request data');
      }

      // ✅ Check if task already exists for this request (prevent duplicates)
      final existingTask =
          await Supabase.instance.client
              .from('tasks')
              .select('idTask')
              .eq('requestID', requestId)
              .maybeSingle();

      if (existingTask != null) {
        print(
          '⚠️ Task already exists for requestID $requestId - skipping creation',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Esta solicitud ya fue procesada'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      print('🔍 Accepting request:');
      print('   requestId: $requestId');
      print('   articleId: $articleId');
      print('   companyId: $companyId');

      // ✅ Show loading dialog to prevent double-tap
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => const Center(
                child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
              ),
        );
      }

      // 1. Update request status to 'aprobado'
      await Supabase.instance.client
          .from('request')
          .update({
            'status': 'aprobado',
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idRequest', requestId);

      print('✅ Request $requestId approved');

      // 2. ✅ Create task with "sin_asignar" status (no employee assigned yet)
      final taskInsertResponse =
          await Supabase.instance.client
              .from('tasks')
              .insert({
                'articleID': articleId,
                'companyID': companyId,
                'requestID': requestId,
                'assignedDate': DateTime.now().toIso8601String(),
                'workflowStatus': 'sin_asignar',
                'state': 1,
                'lastUpdate': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      final createdTaskId = taskInsertResponse['idTask'];
      print('✅ Task created with "sin_asignar" status (ID: $createdTaskId)');

      // 3. ✅ Verify task was created
      final verifyTask =
          await Supabase.instance.client
              .from('tasks')
              .select()
              .eq('requestID', requestId)
              .maybeSingle();

      print(
        '🔍 Verification - Task in DB: ${verifyTask != null ? "FOUND (ID: ${verifyTask['idTask']})" : "NOT FOUND"}',
      );
      if (verifyTask != null) {
        print(
          '   Task details: workflowStatus=${verifyTask['workflowStatus']}, articleID=${verifyTask['articleID']}, companyID=${verifyTask['companyID']}',
        );
      } else {
        throw Exception(
          'Task creation failed - not found in database after insert',
        );
      }

      // ✅ Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Solicitud aprobada'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingRequests(); // Refresh list
      }
    } catch (e) {
      // ✅ Close loading dialog on error
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Error accepting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✅ Handle reject request
  Future<void> _handleRejectRequest(Map<String, dynamic> requestData) async {
    try {
      final requestId = requestData['idRequest'];

      await Supabase.instance.client
          .from('request')
          .update({
            'status': 'rechazado',
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idRequest', requestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Solicitud rechazada'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingRequests(); // Refresh list
      }
    } catch (e) {
      print('❌ Error rejecting request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        return '$hour:$minute';
      }
      return timeStr;
    } catch (e) {
      return timeStr;
    }
  }

  /// ✅ Format scheduled date and time in human-readable Spanish format
  String _formatScheduledDateTime(
    String? dateStr,
    String? startTimeStr,
    String? endTimeStr,
  ) {
    if (dateStr == null || startTimeStr == null) return 'No especificado';

    try {
      final date = DateTime.parse(dateStr);
      final dayNames = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];
      final monthNames = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];

      final dayName = dayNames[date.weekday - 1];
      final day = date.day;
      final monthName = monthNames[date.month - 1];
      final startTime = _formatTime(startTimeStr);

      if (endTimeStr != null) {
        final endTime = _formatTime(endTimeStr);
        return '$dayName $day de $monthName a las $startTime - $endTime';
      } else {
        return '$dayName $day de $monthName a las $startTime';
      }
    } catch (e) {
      return '$dateStr a las ${_formatTime(startTimeStr)}';
    }
  }

  /// ✅ Show employee assignment dialog for already approved request
  void _showAssignEmployeeDialog(Request approvedRequest) {
    // Debug: Check employee list before showing dialog
    print('🔍 DEBUG: _employees.length = ${_employees.length}');
    print('🔍 DEBUG: _employees.isEmpty = ${_employees.isEmpty}');
    print('🔍 DEBUG: _employees = $_employees');

    final scheduledDay = approvedRequest.scheduledDay ?? 'No especificado';
    final startTime = approvedRequest.scheduledStartTime;
    final endTime = approvedRequest.scheduledEndTime;
    final formattedStartTime =
        startTime != null ? _formatTime(startTime) : 'No especificado';
    final formattedEndTime =
        endTime != null ? _formatTime(endTime) : 'No especificado';

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Asignar Empleado'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un empleado para esta tarea:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.article,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Día: $scheduledDay',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Horario: $formattedStartTime - $formattedEndTime',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (_employees.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No hay empleados disponibles'),
                      ),
                    )
                  else
                    ..._employees.map((employee) {
                      final user = employee['users'] as Map<String, dynamic>?;
                      final name = user?['names'] ?? 'Empleado';
                      final email = user?['email'] ?? '';
                      final employeeId = employee['employeeId'] as int?;
                      final isAssigned =
                          employeeId != null &&
                          _assignedEmployeeIds.contains(employeeId);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              isAssigned
                                  ? Colors.grey
                                  : const Color(0xFF2D8A8A),
                          child: Text(name[0].toUpperCase()),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isAssigned ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isAssigned ? Colors.grey : Colors.black54,
                              ),
                            ),
                            if (isAssigned)
                              const Text(
                                'Ya asignado a esta tarea',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        enabled: !isAssigned,
                        onTap:
                            isAssigned
                                ? null
                                : () async {
                                  if (employeeId != null) {
                                    // Show confirmation dialog
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (confirmCtx) => AlertDialog(
                                            title: const Text(
                                              'Confirmar Asignación',
                                            ),
                                            content: Text(
                                              '¿Deseas asignar a $name para recoger "${widget.item.title}"?\n\n'
                                              'Día: $scheduledDay\n'
                                              'Horario: $formattedStartTime - $formattedEndTime',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      confirmCtx,
                                                      false,
                                                    ),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      confirmCtx,
                                                      true,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF2D8A8A,
                                                  ),
                                                ),
                                                child: const Text('Asignar'),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirmed == true) {
                                      Navigator.pop(
                                        ctx,
                                      ); // Close employee selector

                                      // Extract required parameters from approvedRequest
                                      final requestId = approvedRequest.id!;
                                      final companyId =
                                          approvedRequest.companyId!;

                                      await _assignEmployeeToApprovedRequest(
                                        requestId,
                                        employeeId,
                                        companyId,
                                      );
                                    }
                                  } else {
                                    print('❌ Error: employeeId is null');
                                  }
                                },
                      );
                    }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  /// ✅ Show employee assignment confirmation dialog
  void _showAssignEmployeeConfirmation(Map<String, dynamic> request) {
    final scheduledDay =
        request['scheduledDay'] as String? ?? 'No especificado';
    final scheduledStartTime = request['scheduledStartTime'] as String?;
    final scheduledEndTime = request['scheduledEndTime'] as String?;
    final formattedStartTime =
        scheduledStartTime != null
            ? _formatTime(scheduledStartTime)
            : 'No especificado';
    final formattedEndTime =
        scheduledEndTime != null
            ? _formatTime(scheduledEndTime)
            : 'No especificado';

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Asignar empleado antes de aprobar'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selecciona un empleado para esta tarea:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.article,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.item.title,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Día: $scheduledDay',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Color(0xFF2D8A8A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Horario: $formattedStartTime - $formattedEndTime',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  if (_employees.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text('No hay empleados disponibles'),
                      ),
                    )
                  else
                    ..._employees.map((employee) {
                      final user = employee['users'] as Map<String, dynamic>?;
                      final name = user?['names'] ?? 'Empleado';
                      final email = user?['email'] ?? '';
                      final employeeId = employee['employeeId'] as int?;
                      final isAssigned =
                          employeeId != null &&
                          _assignedEmployeeIds.contains(employeeId);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              isAssigned
                                  ? Colors.grey
                                  : const Color(0xFF2D8A8A),
                          child: Text(name[0].toUpperCase()),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            color: isAssigned ? Colors.grey : Colors.black,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isAssigned ? Colors.grey : Colors.black54,
                              ),
                            ),
                            if (isAssigned)
                              const Text(
                                'Ya asignado a esta tarea',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        enabled: !isAssigned,
                        onTap:
                            isAssigned
                                ? null
                                : () async {
                                  if (employeeId != null) {
                                    // Show confirmation dialog
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (confirmCtx) => AlertDialog(
                                            title: const Text(
                                              'Confirmar Asignación',
                                            ),
                                            content: Text(
                                              '¿Deseas asignar a $name para recoger "${widget.item.title}"?\n\n'
                                              'Día: $scheduledDay\n'
                                              'Horario: $formattedStartTime - $formattedEndTime',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      confirmCtx,
                                                      false,
                                                    ),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed:
                                                    () => Navigator.pop(
                                                      confirmCtx,
                                                      true,
                                                    ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF2D8A8A,
                                                  ),
                                                ),
                                                child: const Text('Asignar'),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirmed == true) {
                                      Navigator.pop(
                                        ctx,
                                      ); // Close employee selector

                                      // Extract required parameters from request
                                      final requestId =
                                          request['idRequest'] as int;
                                      final company =
                                          request['company']
                                              as Map<String, dynamic>?;
                                      final companyId =
                                          company?['idCompany'] as int;

                                      await _assignEmployeeToApprovedRequest(
                                        requestId,
                                        employeeId,
                                        companyId,
                                      );
                                    }
                                  } else {
                                    print('❌ Error: employeeId is null');
                                  }
                                },
                      );
                    }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
            ],
          ),
    );
  }

  /// ✅ Accept request and assign employee to task
  // Future<void> _acceptAndAssignEmployee(Map<String, dynamic> requestData, int employeeId) async {
  //   try {
  //     final requestId = requestData['idRequest'] as int;

  //     // ✅ Use widget.item.id for articleId since we're on the detail screen
  //     final articleId = widget.item.id;

  //     // ✅ Try to get companyId from requestData, or from the request itself
  //     int? companyId = requestData['company']?['idCompany'] as int?;

  //     // If not available in requestData, get it from the request directly
  //     if (companyId == null) {
  //       final requestFromDb = await Supabase.instance.client
  //           .from('request')
  //           .select('companyID')
  //           .eq('idRequest', requestId)
  //           .single();
  //       companyId = requestFromDb['companyID'] as int;
  //     }

  //     // First approve the request - update via Supabase directly
  //     await Supabase.instance.client
  //         .from('request')
  //         .update({'status': 'aprobado', 'lastUpdate': DateTime.now().toIso8601String()})
  //         .eq('idRequest', requestId);

  //     // ✅ Create task with employee assigned and "en_proceso" status
  //     final task = Task(
  //       employeeId: employeeId,
  //       articleId: articleId,
  //       companyId: companyId,
  //       requestId: requestId,
  //       assignedDate: DateTime.now(),
  //       workflowStatus: 'en_proceso', // ✅ Employee starts working immediately
  //       state: 1,
  //       lastUpdate: DateTime.now(),
  //     );

  //     await taskDatabase.createTask(task);

  //     print('✅ Task created with employee assigned - Employee: $employeeId working on Article: $articleId');

  //     // ✅ Refresh assigned employees list
  //     await _loadAssignedEmployees();

  //     setState(() {
  //       _pendingRequests.removeWhere((r) => r['idRequest'] == requestId);
  //     });

  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(
  //           content: Text('✅ Solicitud aprobada y empleado asignado'),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //   } catch (e) {
  //     print('❌ Error accepting and assigning: $e');
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text('❌ Error: $e'),
  //           backgroundColor: Colors.red,
  //         ),
  //       );
  //     }
  //   }
  // }

  /// ✅ Assign employee to an already approved request (update existing task)
  Future<void> _assignEmployeeToApprovedRequest(
    int requestId,
    int employeeId,
    int companyId,
  ) async {
    try {
      print('🔍 Attempting to assign employee:');
      print('   requestId: $requestId');
      print('   employeeId: $employeeId');
      print('   companyId: $companyId');

      // ✅ Get existing task created by distributor with "sin_asignar" status
      final existingTask = await taskDatabase.getTaskByRequestId(requestId);

      print(
        '🔍 Task lookup result: ${existingTask != null ? "FOUND (ID: ${existingTask.idTask})" : "NOT FOUND"}',
      );

      if (existingTask == null) {
        // ✅ Debug: Check if task exists in database directly
        final directCheck =
            await Supabase.instance.client
                .from('tasks')
                .select()
                .eq('requestID', requestId)
                .maybeSingle();

        print(
          '🔍 Direct DB check for requestID=$requestId: ${directCheck != null ? "FOUND" : "NOT FOUND"}',
        );
        if (directCheck != null) {
          print('   Task in DB: $directCheck');
        }

        throw Exception(
          'No se encontró la tarea para esta solicitud (requestID: $requestId)',
        );
      }

      print('✅ Found existing task: ${existingTask.toString()}');

      // ✅ Update task to assign employee and change status to "en_proceso"
      final updatedTask = Task(
        idTask: existingTask.idTask,
        employeeId: employeeId, // ✅ Assign employee
        articleId: widget.item.id,
        companyId: companyId,
        requestId: requestId,
        assignedDate: existingTask.assignedDate,
        workflowStatus: 'en_proceso', // ✅ Employee starts working immediately
        state: 1,
        lastUpdate: DateTime.now(),
      );

      await taskDatabase.updateTask(updatedTask);

      print(
        '✅ Task updated successfully - Employee: $employeeId assigned and working on Article: ${widget.item.id}',
      );

      // ✅ Refresh assigned employees list
      await _loadAssignedEmployees();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Empleado asignado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error assigning employee: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al asignar empleado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ Step 1: Confirm arrival at meeting point
  void _showConfirmArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Punto de Encuentro',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Te encuentras en el punto de encuentro?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.place, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.item.address}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Importante: Confirma solo si ya estás en el lugar. Esta acción notificará al otro participante que ya te encuentras en el lugar.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('rechazar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showConfirmObjectReceivedDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('confirmar'),
              ),
            ],
          ),
    );
  }

  /// ✅ Step 2: Confirm object received
  void _showConfirmObjectReceivedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Confirmar Entrega',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Recibiste el objeto?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.item.title}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Importante: confirma solo si realmente recogiste el objeto del usuario.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('rechazar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showRatingDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('confirmar'),
              ),
            ],
          ),
    );
  }

  /// ✅ Step 3: Submit rating and complete task
  void _showRatingDialog() {
    int rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.star, color: Colors.amber),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Calificar entrega',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Cómo fue tu experiencia de la entrega?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Star rating
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                iconSize: 36,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                onPressed: () {
                                  setState(() {
                                    rating = index + 1;
                                  });
                                },
                                icon: Icon(
                                  index < rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Comment input
                        const Text(
                          'Comenta tu experiencia con la entrega',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: commentController,
                          maxLines: 4,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText: 'Escribe tu comentario...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2D8A8A),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '${commentController.text.length}/200',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed:
                          rating > 0
                              ? () async {
                                Navigator.pop(ctx);
                                await _submitReviewAndCompleteTask(
                                  rating,
                                  commentController.text.trim(),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D8A8A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: const Text('Calificar'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// ✅ Distributor: Confirm object delivery
  void _showConfirmDeliveryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in,
                    color: Color(0xFF2D8A8A),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Confirmar Entrega',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Entregaste el objeto?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2, color: Color(0xFF2D8A8A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '"${widget.item.title}"',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Importante: confirma solo si realmente entregaste el objeto a la empresa.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: Colors.grey),
                child: const Text('rechazar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showDistributorRatingDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  foregroundColor: Colors.white,
                ),
                child: const Text('confirmar'),
              ),
            ],
          ),
    );
  }

  /// ✅ Distributor: Submit rating for employee/company
  void _showDistributorRatingDialog() {
    int rating = 0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text(
                    'Califica la experiencia',
                    style: TextStyle(fontSize: 18),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Cómo fue tu experiencia con la empresa?',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        // Star rating
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (index) {
                              return IconButton(
                                iconSize: 36,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    rating = index + 1;
                                  });
                                },
                                icon: Icon(
                                  index < rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Comment field
                        TextField(
                          controller: commentController,
                          maxLength: 200,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Escribe un comentario (opcional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2D8A8A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed:
                          rating > 0
                              ? () {
                                Navigator.pop(ctx);
                                _submitDistributorReviewAndCompleteTask(
                                  rating,
                                  commentController.text.trim(),
                                );
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D8A8A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Enviar'),
                    ),
                  ],
                ),
          ),
    );
  }

  /// ✅ Distributor: Submit review and complete task
  Future<void> _submitDistributorReviewAndCompleteTask(
    int rating,
    String comment,
  ) async {
    if (_distributorTaskId == null ||
        _currentUserId == null ||
        _distributorEmployeeUserId == null) {
      print('❌ Missing required data for distributor review');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error: Información del empleado no disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
            ),
      );

      // Create review - distributor reviews the employee/company
      // ✅ Use _distributorEmployeeUserId (userID) instead of _distributorEmployeeId (employeeID)
      final reviewResponse =
          await Supabase.instance.client
              .from('reviews')
              .insert({
                'starID': rating,
                'articleID': widget.item.id,
                'senderID': _currentUserId, // Distributor sending review
                'receiverID':
                    _distributorEmployeeUserId, // Employee's userID receiving review
                'comment': comment.isEmpty ? 'sin comentario' : comment,
                'state': 1,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      final reviewId = reviewResponse['idReview'] as int;
      print('✅ Distributor review created successfully - Review ID: $reviewId');

      // ✅ Check if employee has already confirmed (status should be 'esperando_confirmacion_distribuidor')
      final taskData =
          await Supabase.instance.client
              .from('tasks')
              .select('workflowStatus')
              .eq('idTask', _distributorTaskId!)
              .single();

      final currentStatus = taskData['workflowStatus'] as String?;

      // Only mark as completado if employee has confirmed (status is 'esperando_confirmacion_distribuidor')
      // Otherwise, mark as 'esperando_confirmacion_empleado'
      String newStatus;
      String message;
      bool taskCompleted = false;

      if (currentStatus == 'esperando_confirmacion_distribuidor') {
        // Employee already confirmed, now distributor confirms → completado
        newStatus = 'completado';
        message = '✅ ¡Entrega completada exitosamente!';
        taskCompleted = true;
        print('✅ Task marked as completado - both parties confirmed');
      } else {
        // Distributor confirms first, waiting for employee
        newStatus = 'esperando_confirmacion_empleado';
        message =
            '✅ Confirmación enviada. Esperando confirmación del empleado.';
        print(
          '✅ Task marked as esperando_confirmacion_empleado - waiting for employee',
        );
      }

      // Update task status
      await Supabase.instance.client
          .from('tasks')
          .update({
            'workflowStatus': newStatus,
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idTask', _distributorTaskId!);

      // ℹ️ Note: Employees do NOT receive points in userPointsLog (Option B)
      // Only distributors receive points when employees review them
      print('ℹ️ Distributor reviewed employee (rating: $rating stars)');
      print('   📝 Review ID: $reviewId saved to reviews table');
      print(
        '   ❌ No userPointsLog entry for employee (only distributors earn XP points)',
      );
      print('   📊 Task Status: $newStatus');

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        // Navigate back to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const NavigationScreens()),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      print('❌ Error submitting distributor review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// ✅ Submit review and complete task
  Future<void> _submitReviewAndCompleteTask(int rating, String comment) async {
    if (_employeeTaskId == null || _currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Error: Información de tarea no disponible'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
            ),
      );

      // 1. Create review
      final reviewResponse =
          await Supabase.instance.client
              .from('reviews')
              .insert({
                'starID': rating,
                'articleID': widget.item.id,
                'senderID':
                    _currentUserId, // ✅ Employee who is SENDING the review
                'receiverID':
                    widget
                        .item
                        .ownerUserId, // ✅ Distributor who is RECEIVING the review
                'comment': comment.isEmpty ? 'sin comentario' : comment,
                'state': 1,
                'created_at': DateTime.now().toIso8601String(),
              })
              .select()
              .single();

      final reviewId = reviewResponse['idReview'] as int;
      print('✅ Review created - Rating: $rating stars, Review ID: $reviewId');

      // 2. Check current task status to determine next status
      final taskData =
          await Supabase.instance.client
              .from('tasks')
              .select('workflowStatus')
              .eq('idTask', _employeeTaskId!)
              .single();

      final currentStatus = taskData['workflowStatus'] as String?;

      // Determine new status based on current workflow
      String newStatus;
      String message;
      bool taskCompleted = false;

      if (currentStatus == 'esperando_confirmacion_empleado') {
        // Distributor already confirmed, now employee confirms → completado
        newStatus = 'completado';
        message = '✅ ¡Entrega completada exitosamente!';
        taskCompleted = true;
        print('✅ Task marked as completado - both parties confirmed');
      } else {
        // Employee confirms first, waiting for distributor
        newStatus = 'esperando_confirmacion_distribuidor';
        message =
            '✅ Confirmación enviada. Esperando confirmación del distribuidor.';
        print(
          '✅ Task marked as esperando_confirmacion_distribuidor - waiting for distributor',
        );
      }

      // Update task status
      await Supabase.instance.client
          .from('tasks')
          .update({
            'workflowStatus': newStatus,
            'lastUpdate': DateTime.now().toIso8601String(),
          })
          .eq('idTask', _employeeTaskId!);

      // ✅ 3. Create userPointsLog for distributor IMMEDIATELY (don't wait for task completion)
      // Employee reviews distributor → distributor gets points right away
      // Distributor confirmation is just for UI/workflow (notification), but points are already recorded
      print(
        '🎯 EMPLOYEE REVIEWED DISTRIBUTOR! Creating userPointsLog IMMEDIATELY...',
      );
      print('   📋 Distributor UserID: ${widget.item.ownerUserId}');
      print('   📦 Article ID: ${widget.item.id}');
      print('   ⭐ Rating given by employee: $rating stars');
      print('   📝 Review ID: $reviewId');
      print(
        '   📊 Task Status: $newStatus (will wait for distributor confirmation for UI only)',
      );

      try {
        // Get current active cycle
        print('   🔍 Querying active cycle (state=1)...');
        final now = DateTime.now();

        final cycleData =
            await Supabase.instance.client
                .from('cycle')
                .select('idCycle, startDate, endDate, name')
                .eq('state', 1)
                .lte('startDate', now.toIso8601String())
                .gte('endDate', now.toIso8601String())
                .maybeSingle();

        final cycleId = cycleData?['idCycle'] as int?;

        if (cycleId != null) {
          final cycleName = cycleData?['name'] ?? 'Ciclo ${cycleId}';
          final startDate = cycleData?['startDate'] ?? 'N/A';
          final endDate = cycleData?['endDate'] ?? 'N/A';

          print('   ✅ Active cycle found for current period:');
          print('      🆔 Cycle ID: $cycleId');
          print('      📛 Cycle Name: $cycleName');
          print('      📅 Period: $startDate to $endDate');
          print('      🕒 Current Date: ${now.toIso8601String()}');

          // Get points from starValue table based on rating
          print('   🔍 Querying starValue for rating $rating...');
          final starValueData =
              await Supabase.instance.client
                  .from('starValue')
                  .select('points')
                  .eq('idStarValue', rating)
                  .single();

          final points = starValueData['points'] as int;
          print('   ✅ Points for rating $rating: $points XP');

          // Create points log entry for distributor
          final pointsLog = userPointsLog(
            userId: widget.item.ownerUserId, // ✅ Distributor receives points
            articleId: widget.item.id,
            reviewId: reviewId,
            cycleId: cycleId,
            points: points,
            reason: 'Puntos obtenidos por el artículo: ${widget.item.title}',
            type: 'bono',
            state: 1,
            lastUpdate: DateTime.now(),
          );

          print(
            '   📝 INSERTING userPointsLog into database for DISTRIBUTOR...',
          );
          await pointsLogDatabase.createPointsLog(pointsLog);

          print('✅✅✅ SUCCESS! UserPointsLog CREATED for DISTRIBUTOR:');
          print('      👤 UserID: ${widget.item.ownerUserId} (Distributor)');
          print('      🎁 Points Awarded: $points XP');
          print('      📦 Article: ${widget.item.title}');
          print('      🔄 Cycle: $cycleId');
          print(
            '      ⏰ Created immediately - NOT waiting for distributor confirmation',
          );
        } else {
          print(
            '⚠️⚠️⚠️ WARNING: No active cycle found (state=1) - userPointsLog NOT created for distributor',
          );
        }
      } catch (e) {
        print('❌❌❌ ERROR creating userPointsLog for DISTRIBUTOR: $e');
        print('   Stack trace: ${StackTrace.current}');
        // Don't fail the whole operation if points log fails
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );

        // Navigate back to home
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const EmployeeNavigationScreens(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      print('❌ Error submitting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _initializeBasicData() {
    // Store original data
    _originalTitle = widget.item.title;
    _originalDescription = widget.item.description ?? '';
    _originalCategoryName = widget.item.categoryName;
    _originalConditionName = widget.item.condition ?? '';
    _originalAddress = widget.item.address;
    _originalLocation = LatLng(widget.item.latitude, widget.item.longitude);

    // Initialize controllers with current data
    _itemNameController.text = widget.item.title;
    _descriptionController.text = widget.item.description ?? '';
    _selectedLocation = LatLng(widget.item.latitude, widget.item.longitude);
    _selectedAddress = widget.item.address;

    _selectedCondition = widget.item.condition;

    // initializar el categoria seleccionado con el articulo actual
    _selectedCategory = Category(
      id: widget.item.categoryID ?? 0,
      name: widget.item.categoryName,
    );
  }

  /// ✅ Load availability data from daysAvailable table
  Future<void> _loadAvailabilityData() async {
    try {
      print(
        '🔍 Loading availability data from daysAvailable table for article ${widget.item.id}...',
      );

      final daysAvailableList = await Supabase.instance.client
          .from('daysAvailable')
          .select()
          .eq('articleID', widget.item.id)
          .order('dateAvailable', ascending: true);

      if (daysAvailableList.isEmpty) {
        print('❌ No availability data found');
        setState(() {
          _originalAvailability = null;
          _selectedAvailability = null;
        });
        return;
      }

      print('✅ Found ${daysAvailableList.length} availability records');

      // Build per-day times map
      final Map<String, DayTimeRange> perDayTimes = {};
      final dayNames = [
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
        'Domingo',
      ];

      for (var record in daysAvailableList) {
        final date = DateTime.parse(record['dateAvailable']);
        final dayName = dayNames[date.weekday - 1];

        final startTime = _parseTimeFromDatabase(record['startTime']);
        final endTime = _parseTimeFromDatabase(record['endTime']);

        if (startTime != null && endTime != null) {
          // ✅ Use date string as unique key (format: yyyy-MM-dd)
          final dateKey =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

          perDayTimes[dateKey] = DayTimeRange(
            dayName: dayName,
            date: date,
            startTime: startTime,
            endTime: endTime,
          );

          print(
            '   $dayName (${date.day}/${date.month}) [$dateKey]: ${_formatTimeForLog(startTime)} - ${_formatTimeForLog(endTime)}',
          );
        }
      }

      if (perDayTimes.isNotEmpty) {
        final availabilityData = AvailabilityData(
          selectedDays: perDayTimes.keys.toList(),
          startTime: null,
          endTime: null,
          perDayTimes: perDayTimes,
        );

        setState(() {
          _originalAvailability = availabilityData;
          _selectedAvailability = availabilityData;
        });

        print('✅ Availability data loaded successfully');
      } else {
        print('❌ No valid availability records found');
        setState(() {
          _originalAvailability = null;
          _selectedAvailability = null;
        });
      }
    } catch (e) {
      print('❌ Error loading availability data: $e');
      setState(() {
        _originalAvailability = null;
        _selectedAvailability = null;
      });
    }
  }

  TimeOfDay? _parseTimeFromDatabase(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print('Error parsing time from database: $e');
      return null;
    }
  }

  String _formatTimeForLog(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _onImagesChanged(List<XFile> images) {
    setState(() {
      pickedImages = images;
    });
  }

  Future<void> _loadPhotos() async {
    try {
      setState(() {
        _isLoadingPhotos = true;
      });

      print('🔍 Intentando cargar fotos para artículo ID: ${widget.item.id}');

      // Build URL pattern for this article (e.g., "articles/5")
      final urlPattern = 'articles/${widget.item.id}';

      // load all photos for this article using URL pattern
      final photos = await mediaDatabase.getPhotosByPattern(urlPattern);
      final mainPhoto = await mediaDatabase.getMainPhotoByPattern(urlPattern);

      setState(() {
        _photos = photos;
        _mainPhoto = mainPhoto;
        _isLoadingPhotos = false;
      });

      print(
        '✅ Cargadas ${_photos.length} fotos para artículo ${widget.item.id}',
      );
      if (_mainPhoto != null) {
        print('✅ Foto principal encontrada: ${_mainPhoto!.fileName}');
      } else {
        print('⚠️ No se encontró foto principal');
      }

      // Debug: Print photo details
      for (int i = 0; i < _photos.length; i++) {
        final photo = _photos[i];
        print('📸 Foto ${i + 1}: ${photo.fileName} - URL: ${photo.url}');
      }
    } catch (e) {
      setState(() {
        _isLoadingPhotos = false;
      });
      print('❌ Error loading photos: $e');
      print('   Stack trace: ${StackTrace.current}');
    }
  }

  // ✅ Open cropper for image (same as RegisterRecycle)
  Future<XFile> _openCropper(BuildContext context, XFile file) async {
    try {
      final res = await Navigator.of(context).push<XFile>(
        MaterialPageRoute(builder: (_) => Fixed43Cropper(file: file)),
      );
      return res ?? file;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return file;
    }
  }

  Future<void> _addPhoto() async {
    try {
      // Check photo limit (including existing photos + picked images)
      final totalPhotos =
          _photos.length + (_mainPhoto != null ? 1 : 0) + pickedImages.length;
      if (totalPhotos >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Límite de 10 fotos alcanzado'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // ✅ Show dialog to choose between camera or gallery
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Seleccionar foto'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Color(0xFF2D8A8A),
                  ),
                  title: const Text('Tomar foto'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library,
                    color: Color(0xFF2D8A8A),
                  ),
                  title: const Text('Seleccionar de galería'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return; // User cancelled

      setState(() => _isUploadingPhoto = true);

      List<XFile>? newImages;

      if (source == ImageSource.camera) {
        // ✅ Take a single photo with camera
        final XFile? photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );

        if (photo != null) {
          // ✅ Crop the camera photo
          final croppedPhoto = await _openCropper(context, photo);
          newImages = [croppedPhoto];
        }
      } else {
        // ✅ Pick multiple images from gallery
        final pickedImages = await _imagePicker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 80,
        );

        if (pickedImages.isNotEmpty) {
          // ✅ Crop each image sequentially
          final List<XFile> croppedImages = [];
          for (final image in pickedImages) {
            final cropped = await _openCropper(context, image);
            croppedImages.add(cropped);
          }
          newImages = croppedImages;
        }
      }

      if (newImages != null && newImages.isNotEmpty) {
        // Calculate remaining slots
        final remainingSlots = 10 - totalPhotos;
        final imagesToAdd = newImages.take(remainingSlots).toList();

        // Add to picked images list
        _onImagesChanged([...pickedImages, ...imagesToAdd]);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${imagesToAdd.length} foto(s) seleccionada(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  // ✅ Helper method to upload a single photo with retry logic
  Future<String> _uploadSinglePhoto(
    XFile image,
    String filePath,
    int maxRetries,
  ) async {
    final storage = Supabase.instance.client.storage;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print('📤 Upload attempt ${attempt + 1}/$maxRetries for: $filePath');

        // Read the file as bytes
        final bytes = await image.readAsBytes();

        // Small delay between retries to allow connection recovery
        if (attempt > 0) {
          await Future.delayed(Duration(seconds: attempt));
        }

        // Upload to supabase storage with timeout
        await storage
            .from('multimedia')
            .uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            )
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Upload timeout after 30 seconds');
              },
            );

        // Get the public url
        final publicUrl = storage.from('multimedia').getPublicUrl(filePath);
        print('✅ Upload successful: $filePath');

        return publicUrl;
      } catch (e) {
        attempt++;
        print('⚠️ Upload attempt $attempt failed: $e');

        if (attempt >= maxRetries) {
          print('❌ All upload attempts failed for: $filePath');
          rethrow;
        }

        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: attempt * 2));
      }
    }

    throw Exception('Failed to upload after $maxRetries attempts');
  }

  Future<void> _uploadAndSavePhotos(int articleId, String userId) async {
    if (pickedImages.isEmpty) return;

    setState(() {
      _isUploadingPhoto = true;
    }); // Track successfully uploaded photos for cleanup on failure
    List<String> uploadedPaths = [];

    try {
      // Build URL pattern for this article
      final urlPattern = 'articles/$articleId';

      // Get the current photos count to continue the upload order sequence
      final existingPhotosCount = await mediaDatabase.getPhotosCountByPattern(
        urlPattern,
      );

      // Check if article already has a main photo
      final bool hasMainPhoto = await mediaDatabase.hasMainPhoto(urlPattern);

      for (int i = 0; i < pickedImages.length; i++) {
        final image = pickedImages[i];

        // Calculate the proper upload order (continue from existing photos)
        final uploadOrder = existingPhotosCount + i;

        // Clean the image name and create a unique filename
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final extension = image.name.split('.').last.toLowerCase();

        //validate file extension
        if (!['jpg', 'jpeg', 'png'].contains(extension)) {
          throw Exception('Formato de imagen no valido: $extension');
        }

        // Use the calculated upload order in filename
        final fileName =
            '${timestamp}_${uploadOrder}_article_${articleId}.$extension';
        final filePath = 'articles/$articleId/$fileName';

        print('📸 Processing photo ${i + 1}/${pickedImages.length}: $fileName');

        // ✅ Upload with retry logic (3 attempts)
        final publicUrl = await _uploadSinglePhoto(image, filePath, 3);
        uploadedPaths.add(filePath);

        // Read bytes for file size
        final bytes = await image.readAsBytes();

        // Create photo record in the database
        final newMedia = Multimedia(
          url: publicUrl,
          fileName: fileName,
          filePath: filePath,
          fileSize: bytes.length,
          mimeType: 'image/$extension',
          isMain:
              !hasMainPhoto &&
              i ==
                  0, // First new image becomes main only if no main photo exists
          uploadOrder: uploadOrder, // Use calculated upload order
          entityType: 'article', // ✅ Identificar tipo de entidad
          entityId: articleId, // ✅ ID del artículo
        );

        await mediaDatabase.createPhoto(newMedia);

        print(
          '✅ Photo ${i + 1}/${pickedImages.length} saved: $fileName (uploadOrder: $uploadOrder)',
        );
      }

      // update article's lastUpdate after adding photos
      await articleDatabase.updateArticleLastUpdate(articleId);

      print(
        '✅ Todas las fotos guardadas correctamente para el articulo $articleId',
      );
    } catch (e) {
      print('❌ Error detallado en subir y guardar fotos: $e');

      // ✅ Cleanup: Delete successfully uploaded files if process failed
      if (uploadedPaths.isNotEmpty) {
        print(
          '🧹 Cleaning up ${uploadedPaths.length} uploaded files due to error...',
        );
        for (final path in uploadedPaths) {
          try {
            await Supabase.instance.client.storage.from('multimedia').remove([
              path,
            ]);
            print('🗑️ Deleted: $path');
          } catch (deleteError) {
            print('⚠️ Could not delete $path: $deleteError');
          }
        }
      }

      throw Exception('Error al subir imágenes: $e');
    } finally {
      setState(() {
        _isUploadingPhoto = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await categoryDatabase.getAllCategories();
      setState(() {
        _categories = categories;
        // Find and select the current category
        _selectedCategory = categories.firstWhere(
          (cat) => cat.name == widget.item.categoryName,
          orElse: () => categories.isNotEmpty ? categories.first : Category(),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar categorías: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadDisabledCategories() async {
    if (!_isOwner) return;

    try {
      print(
        '🔄 Recargando categorías bloqueadas para artículo ${widget.item.id}...',
      );

      // ✅ Excluir la categoría del artículo actual
      final disabledIds = await workflowService.getUsedPendingCategoryIds(
        excludeArticleId: widget.item.id,
      );

      if (mounted) {
        setState(() {
          _disabledCategoryIds = disabledIds;
        });
      }

      print(
        '🔒 Categorías bloqueadas para edición del artículo ${widget.item.id}:',
      );
      print('   IDs bloqueados: $_disabledCategoryIds');
      print(
        '   Categoría actual (${widget.item.categoryID} - ${widget.item.categoryName}) está permitida ✅',
      );

      // Debug: Mostrar nombres de categorías bloqueadas
      final blockedNames = _categories
          .where((cat) => _disabledCategoryIds.contains(cat.id))
          .map((cat) => cat.name)
          .join(', ');
      if (blockedNames.isNotEmpty) {
        print('   Categorías bloqueadas por nombre: $blockedNames');
      } else {
        print(
          '   ✅ No hay categorías bloqueadas (usuario puede usar cualquier categoría)',
        );
      }
    } catch (e) {
      print('❌ Error cargando categorías bloqueadas: $e');
    }
  }

  // Deliver? updatedDeliver;

  Future<void> _saveChanges() async {
    // if (!_formKey.currentState!.validate()) {
    //   return;
    // }

    if (_selectedCategory != null &&
        _disabledCategoryIds.contains(_selectedCategory!.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes cambiar a esta categoría porque ya tienes otro artículo pendiente con ella',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    bool hasChanges = false;

    if (_itemNameController.text.trim() != _originalTitle) hasChanges = true;
    if (_descriptionController.text.trim() != _originalDescription)
      hasChanges = true;
    if (_selectedCategory?.name != _originalCategoryName) hasChanges = true;
    if (_selectedCondition != _originalConditionName) hasChanges = true;
    if (_selectedAddress != _originalAddress) hasChanges = true;
    if (_selectedLocation != _originalLocation) hasChanges = true;

    // ✅ Check availability changes (properly handles perDayTimes)
    print('🔍 Checking availability changes:');
    print(
      '   _selectedAvailability: ${_selectedAvailability?.selectedDays} (${_selectedAvailability?.perDayTimes?.length} days)',
    );
    print(
      '   _originalAvailability: ${_originalAvailability?.selectedDays} (${_originalAvailability?.perDayTimes?.length} days)',
    );

    if (_selectedAvailability != null && _originalAvailability != null) {
      final isEqual = _selectedAvailability!.isEqualTo(_originalAvailability);
      print('   isEqualTo result: $isEqual');
      if (!isEqual) {
        hasChanges = true;
        print('   ✅ Availability has changed!');
      }
    } else if (_selectedAvailability != _originalAvailability) {
      hasChanges = true;
      print('   ✅ Availability changed (null check)');
    }

    if (_photosToDelete.isNotEmpty) hasChanges = true;

    //check for picked images
    if (pickedImages.isNotEmpty) hasChanges = true;

    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay cambios para actualizar'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. delete marked photos (batch deletion for better performance)
      if (_photosToDelete.isNotEmpty) {
        // check if main photo is being deleted
        bool mainPhotoDeleted = false;
        for (Multimedia photo in _photosToDelete) {
          if (photo.isMain) {
            mainPhotoDeleted = true;
            break;
          }
        }

        // delete all marked photos at once
        await mediaDatabase.deleteMultiplePhotos(_photosToDelete);

        //set new main photo if needed
        if (mainPhotoDeleted) {
          final urlPattern = 'articles/${widget.item.id}';
          await mediaDatabase.setNewMainPhoto(urlPattern);
        }

        // update article's lastUpdate after deleting photos
        await articleDatabase.updateArticleLastUpdate(widget.item.id);

        print('Deleted ${_photosToDelete.length} photos');
      }

      // 2. upload and save new photos if any
      if (pickedImages.isNotEmpty) {
        final userId = widget.item.ownerUserId.toString();
        await _uploadAndSavePhotos(widget.item.id, userId);
        //clear picked images after upload
        setState(() {
          pickedImages.clear();
        });
      }

      // 4. Update article
      Article updatedArticle = Article(
        id: widget.item.id,
        name: _itemNameController.text.trim(),
        description:
            _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
        categoryID: _selectedCategory!.id,
        condition: _selectedCondition,
        address: _selectedAddress,
        lat:
            _selectedLocation?.latitude ??
            widget.item.latitude, // ✅ Use new location if changed
        lng:
            _selectedLocation?.longitude ??
            widget.item.longitude, // ✅ Use new location if changed
        userId: widget.item.ownerUserId,
        // workflowStatus: 'pendiente',
        state: 1,
      );

      await articleDatabase.updateArticle(updatedArticle);

      // Update daysAvailable records - delete old and create new ones
      if (_selectedAvailability != null) {
        await _updateDaysAvailableRecords(
          widget.item.id,
          _selectedAvailability!,
        );
      }

      // 5. reload photos to update UI
      await _loadPhotos();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Artículo actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditing = false;
        _isSubmitting = false;
        _photosToDelete.clear();
      });

      // Update original values
      _originalTitle = _itemNameController.text.trim();
      _originalDescription = _descriptionController.text.trim();
      _originalCategoryName = _selectedCategory!.name!;
      _originalConditionName = _selectedCondition ?? '';
      _originalAddress = _selectedAddress!;
      _originalLocation = _selectedLocation!;
      _originalAvailability = _selectedAvailability;

      // ✅ Recargar categorías bloqueadas después de guardar
      await _loadDisabledCategories();
      print('🔄 Categorías bloqueadas actualizadas después de guardar cambios');

      // ✅ Navigate back to home screen with reload flag
      if (mounted) {
        Navigator.pop(
          context,
          true,
        ); // Return true to indicate changes were made
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Helper method to update daysAvailable records
  /// Deletes all existing records and creates new ones
  Future<void> _updateDaysAvailableRecords(
    int articleId,
    AvailabilityData availability,
  ) async {
    // First, get all existing daysAvailable records for this article
    final existingRecords = await Supabase.instance.client
        .from('daysAvailable')
        .select()
        .eq('articleID', articleId);

    // Delete all existing records
    for (var record in existingRecords) {
      final oldRecord = daysAvailable.fromMap(record);
      if (oldRecord.id != null) {
        await daysAvailableDatabase.deleteDaysAvailable(oldRecord);
      }
    }

    // ✅ Check if we have per-day times (new format)
    if (availability.perDayTimes != null &&
        availability.perDayTimes!.isNotEmpty) {
      for (var entry in availability.perDayTimes!.entries) {
        final dayTimeRange = entry.value;

        final newDaysAvailable = daysAvailable(
          articleId: articleId,
          availableDate: dayTimeRange.date,
          timeStart: _formatTimeForDatabase(dayTimeRange.startTime),
          timeEnd: _formatTimeForDatabase(dayTimeRange.endTime),
        );

        await daysAvailableDatabase.createDaysAvailable(newDaysAvailable);
      }
    } else {
      // ✅ Old format: same time for all days
      final dayNameToWeekday = {
        'Lunes': 1,
        'Martes': 2,
        'Miércoles': 3,
        'Jueves': 4,
        'Viernes': 5,
        'Sábado': 6,
        'Domingo': 7,
      };

      final today = DateTime.now();
      final currentWeekday = today.weekday;
      final monday = today.subtract(Duration(days: currentWeekday - 1));

      for (String dayName in availability.selectedDays) {
        final weekdayNumber = dayNameToWeekday[dayName];
        if (weekdayNumber != null) {
          final date = monday.add(Duration(days: weekdayNumber - 1));

          final newDaysAvailable = daysAvailable(
            articleId: articleId,
            availableDate: date,
            timeStart: availability.getStartTimeForDatabase(),
            timeEnd: availability.getEndTimeForDatabase(),
          );

          await daysAvailableDatabase.createDaysAvailable(newDaysAvailable);
        }
      }
    }
  }

  String _formatTimeForDatabase(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ✅ Load reviewer avatar from multimedia table
  Future<Multimedia?> _loadReviewerAvatar(
    String userId,
    String userRole,
  ) async {
    try {
      final role = userRole.toLowerCase();

      // Try new path first (with role)
      String avatarPattern = 'users/$role/$userId/avatars/';
      Multimedia? avatar = await mediaDatabase.getMainPhotoByPattern(
        avatarPattern,
      );

      // If not found, try old path (without role) for backward compatibility
      if (avatar == null) {
        avatarPattern = 'users/$userId/avatars/';
        avatar = await mediaDatabase.getMainPhotoByPattern(avatarPattern);
      }

      return avatar;
    } catch (e) {
      print('Error loading reviewer avatar: $e');
      return null;
    }
  }

  // ✅ Get role display name
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin-empresa':
        return 'Administrador de Empresa';
      case 'empresa':
        return 'Empresa';
      case 'employee':
        return 'Empleado';
      case 'user':
      default:
        return 'Distribuidor';
    }
  }

  // ✅ Get contextual role label based on sender relationship to article
  String _getContextualRoleLabel(Map<String, dynamic> review) {
    final senderId = review['sender']?['idUser'] as int?;
    final senderRole = review['sender']?['role'] as String?;

    // If sender is the distributor (article owner), they delivered
    if (senderId == widget.item.ownerUserId) {
      return 'Entregado por';
    }

    // If sender is employee or company, they received
    if (senderRole?.toLowerCase() == 'empleado' ||
        senderRole?.toLowerCase() == 'admin-empresa') {
      return 'Recibido por';
    }

    // Default fallback
    return 'Calificado por';
  }

  Future<void> _deleteArticle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirmar eliminación'),
            content: const Text(
              '¿Estás seguro de que quieres eliminar este artículo? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        Article articleToDelete = Article(
          id: widget.item.id,
          name: widget.item.title,
          state: 0, // This will be set in the delete method
        );

        await articleDatabase.deleteArticle(articleToDelete);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Artículo eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );

          // ✅ Navigate back to home screen with reload flag
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate article was deleted
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// ✅ Send request to distributor (for admin-empresa)
  Future<void> _sendRequestToDistributor() async {
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Error: No se pudo obtener la información de la empresa',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Load daysAvailable data for this article
    List<Map<String, dynamic>>? daysAvailableData;
    try {
      final response = await Supabase.instance.client
          .from('daysAvailable')
          .select()
          .eq('articleID', widget.item.id)
          .order('dateAvailable', ascending: true);

      daysAvailableData = response.cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error loading daysAvailable: $e');
    }

    // ✅ Show scheduling dialog to select day and time
    final scheduleData = await showDialog<Map<String, String>>(
      context: context,
      builder:
          (context) => SchedulePickupDialog(
            availableDays: widget.item.availableDays,
            availableTimeStart: widget.item.availableTimeStart,
            availableTimeEnd: widget.item.availableTimeEnd,
            articleName: widget.item.title,
            daysAvailableData: daysAvailableData,
          ),
    );

    if (scheduleData == null) return; // User cancelled

    // Store navigator reference before async operation
    final navigator = Navigator.of(context);

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
          ),
    );

    try {
      // Parse time strings (HH:MM) and format as HH:MM:SS for database
      final startTimeParts = scheduleData['startTime']!.split(':');
      final startTimeFormatted =
          '${startTimeParts[0].padLeft(2, '0')}:${startTimeParts[1].padLeft(2, '0')}:00';

      final endTimeParts = scheduleData['endTime']!.split(':');
      final endTimeFormatted =
          '${endTimeParts[0].padLeft(2, '0')}:${endTimeParts[1].padLeft(2, '0')}:00';

      // Create request with scheduled day and time window
      final newRequest = Request(
        articleId: widget.item.id,
        companyId: _companyId,
        status: 'pendiente',
        requestDate: DateTime.now(),
        state: 1,
        lastUpdate: DateTime.now(),
        scheduledDay: scheduleData['day'],
        scheduledStartTime: startTimeFormatted,
        scheduledEndTime: endTimeFormatted,
      );

      await requestDatabase.createRequest(newRequest);

      // Reload request status
      await _loadUserRoleAndRequest();

      navigator.pop(); // Close loading indicator

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Solicitud enviada para ${scheduleData['day']} entre ${scheduleData['startTime']} - ${scheduleData['endTime']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      navigator.pop(); // Close loading indicator

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar solicitud: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('❌ Error sending request: $e');
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _descriptionController.dispose();
    _taskSubscription?.unsubscribe(); // ✅ Clean up real-time subscription
    super.dispose();
  }

  /// ✅ Build reviews section widget
  Widget _buildReviewsSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'Error al cargar calificaciones',
            style: TextStyle(color: Colors.grey[600]),
          );
        }

        final reviews = snapshot.data ?? [];

        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No hay calificaciones disponibles',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children:
              reviews.map((review) {
                final sender = review['sender'] as Map<String, dynamic>?;
                final senderName = sender?['names'] ?? 'Usuario';
                final rating = review['starID'] as int? ?? 0;
                final comment = review['comment'] as String?;
                final createdAt = review['created_at'] as String?;

                // Format date
                String dateText = '';
                if (createdAt != null) {
                  try {
                    final date = DateTime.parse(createdAt);
                    dateText = '${date.day}/${date.month}/${date.year}';
                  } catch (e) {
                    // Ignore parse error
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(
                              0xFF2D8A8A,
                            ).withOpacity(0.1),
                            child: Text(
                              senderName.isNotEmpty
                                  ? senderName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                color: Color(0xFF2D8A8A),
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (dateText.isNotEmpty)
                                  Text(
                                    dateText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                        ],
                      ),
                      if (comment != null && comment.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            comment,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  /// ✅ Load reviews for this article
  Future<List<Map<String, dynamic>>> _loadReviews() async {
    try {
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('''
            idReview,
            starID,
            comment,
            created_at,
            senderID,
            receiverID,
            sender:senderID(idUser, names, role),
            receiver:receiverID(idUser, names, role)
          ''')
          .eq('articleID', widget.item.id)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(reviews);
    } catch (e) {
      print('❌ Error loading reviews: $e');
      return [];
    }
  }

  /// ✅ Build request card widget
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final company = request['company'] as Map<String, dynamic>?;
    final companyId = company?['idCompany'] as int?;
    final articleId = request['articleID'] as int? ?? widget.item.id;
    final requestId = request['idRequest'] as int?;
    final companyLogo = request['companyLogo'] as Multimedia?;
    final scheduledDay = request['scheduledDay'] as String?;
    final scheduledStartTime = request['scheduledStartTime'] as String?;
    final scheduledEndTime = request['scheduledEndTime'] as String?;
    final companyName = company?['nameCompany'] ?? 'Empresa';

    // ✅ Format the scheduled date and time in human-readable Spanish format
    final formattedDateTime = _formatScheduledDateTime(
      scheduledDay,
      scheduledStartTime,
      scheduledEndTime,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company info
            Row(
              children: [
                // Company logo
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    image:
                        companyLogo?.url != null
                            ? DecorationImage(
                              image: CachedNetworkImageProvider(
                                companyLogo!.url!,
                              ),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      companyLogo?.url == null
                          ? const Icon(
                            Icons.business,
                            color: Color(0xFF2D8A8A),
                            size: 24,
                          )
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                      if (scheduledDay != null && scheduledStartTime != null)
                        Text(
                          formattedDateTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleRejectRequest(request),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Rechazar',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final requestData = {
                        'requestId': requestId,
                        'articleId': articleId,
                        'companyId': companyId,
                        'company': company,
                        'scheduledDay': scheduledDay,
                        'scheduledStartTime': scheduledStartTime,
                        'scheduledEndTime': scheduledEndTime,
                      };

                      // If company admin with employees, show assignment dialog
                      // Otherwise, just accept the request
                      if (_isCompanyAdmin && _employees.isNotEmpty) {
                        _showAssignEmployeeConfirmation(request);
                      } else {
                        _handleAcceptRequest(request);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D8A8A),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isCompanyAdmin && _employees.isNotEmpty
                          ? 'Asignar'
                          : 'Aceptar',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Artículo' : 'Detalles del Artículo'),
        backgroundColor: const Color(0xFF2D8A8A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child:
            _isLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2D8A8A)),
                )
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ✅ Employee-only status badge
                      if (_isEmployee && _employeeTaskStatus == 'en_proceso')
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.work_outline,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'En Proceso',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Esta tarea está asignada a ti',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                      // photo gallery
                      const Text(
                        'Fotos del articulo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      PhotoGalleryWidget(
                        photos: _photos,
                        mainPhoto: _mainPhoto,
                        isLoading: _isLoadingPhotos || _isUploadingPhoto,
                        isOwner: _isOwner,
                        photosToDelete: _photosToDelete,
                        pickedImages: pickedImages,
                        onPhotosToDeleteChanged:
                            _isOwner && _isEditing
                                ? (photosToDelete) {
                                  setState(() {
                                    _photosToDelete = photosToDelete;
                                  });
                                }
                                : null,
                        onPickedImagesChanged:
                            _isOwner && _isEditing
                                ? (updatedImages) {
                                  setState(() {
                                    pickedImages = updatedImages;
                                  });
                                }
                                : null,
                        onAddPhoto:
                            _isOwner && _isEditing
                                ? (pickedImages.length +
                                            _photos.length +
                                            (_mainPhoto != null ? 1 : 0) <
                                        10)
                                    ? _addPhoto
                                    : null
                                : null,
                      ),

                      if (_isOwner && _isEditing) ...[
                        const SizedBox(height: 12),
                        PhotoValidation(
                          allPhotos: [
                            ..._photos,
                            if (_mainPhoto != null) _mainPhoto!,
                          ],
                          photosToDelete: _photosToDelete,
                          pickedImages: pickedImages,
                          mainPhoto: _mainPhoto,
                          maxPhotos: 10,
                        ),
                      ],
                      const SizedBox(height: 20),

                      Text(
                        _isEditing
                            ? 'Edita los datos del artículo'
                            : 'Información del artículo',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D8A8A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Item name field
                      MyTextFormField(
                        controller: _itemNameController,
                        hintText: 'Nombre del artículo',
                        text: 'Nombre del artículo',
                        obscureText: false,
                        isEnabled: _isEditing,
                        prefixIcon: const Icon(Icons.recycling),
                      ),
                      const SizedBox(height: 16),

                      CategoryTags(
                        categories: _categories,
                        selectedCategory: _selectedCategory,
                        onCategorySelected:
                            _isEditing
                                ? (category) {
                                  setState(() {
                                    _selectedCategory = category;
                                  });
                                }
                                : null,
                        disabledCategoryIds: _disabledCategoryIds,
                        labelText: 'Categoría',
                        isEnabled: _isEditing,
                        validator:
                            _isEditing
                                ? (value) {
                                  if (value == null) {
                                    return 'Por favor selecciona una categoría';
                                  }
                                  return null;
                                }
                                : null,
                      ),

                      const SizedBox(height: 16),

                      ConditionSelector(
                        selectedCondition: _selectedCondition,
                        onConditionSelected:
                            _isEditing
                                ? (condition) {
                                  setState(() {
                                    _selectedCondition = condition;
                                  });
                                }
                                : null,
                        labelText: 'Estado',
                        isEnabled: _isEditing,
                        validator:
                            _isEditing
                                ? (value) {
                                  if (value == null) {
                                    return 'Por favor selecciona el estado del artículo';
                                  }
                                  return null;
                                }
                                : null,
                      ),

                      // Description field
                      LimitCharacterTwo(
                        controller: _descriptionController,
                        hintText: 'Describe tu artículo',
                        text: 'Descripción',
                        obscureText: false,
                        isEnabled: _isEditing,
                        isVisible: true,
                      ),
                      const SizedBox(height: 16),

                      LocationMapPreview(
                        location: _selectedLocation ?? _originalLocation,
                        originalLocation: _isEditing ? _originalLocation : null,
                        address: _selectedAddress ?? widget.item.address,
                        isEditing: _isEditing,
                        onLocationChanged:
                            _isEditing
                                ? (location, address) {
                                  setState(() {
                                    _selectedLocation = location;
                                    _selectedAddress = address;
                                  });
                                }
                                : null,
                      ),

                      const SizedBox(height: 16),

                      // ✅ Show scheduled time for employees, distributors, AND company admins with active tasks (but not completed)
                      if (((_isEmployee &&
                              _employeeScheduledDay != null &&
                              _employeeScheduledTime != null &&
                              _employeeTaskStatus != 'completado') ||
                          (_isOwner &&
                              _distributorTaskStatus != null &&
                              _distributorTaskStatus != 'completado' &&
                              _distributorScheduledDay != null &&
                              _distributorScheduledTime != null) ||
                          (!_isOwner &&
                              _isCompanyAdmin &&
                              _companyTaskStatus != null &&
                              _companyTaskStatus != 'completado' &&
                              _companyScheduledDay != null &&
                              _companyScheduledTime != null)))
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                _isEmployee
                                    ? Colors.amber.shade50
                                    : (_isOwner
                                        ? Colors.blue.shade50
                                        : Colors.green.shade50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _isEmployee
                                      ? Colors.amber.shade200
                                      : (_isOwner
                                          ? Colors.blue.shade200
                                          : Colors.green.shade200),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    color:
                                        _isEmployee
                                            ? Colors.amber
                                            : (_isOwner
                                                ? Colors.blue
                                                : Colors.green),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Fecha y Hora de Entrega',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _isEmployee
                                              ? Colors.amber
                                              : (_isOwner
                                                  ? Colors.blue
                                                  : Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 18,
                                    color:
                                        _isEmployee
                                            ? Colors.amber
                                            : (_isOwner
                                                ? Colors.blue
                                                : Colors.green),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _isEmployee
                                          ? _formatScheduledDateTime(
                                            _employeeScheduledDay,
                                            _employeeScheduledTime,
                                            null,
                                          )
                                          : (_isOwner
                                              ? _formatScheduledDateTime(
                                                _distributorScheduledDay,
                                                _distributorScheduledTime,
                                                null,
                                              )
                                              : _formatScheduledDateTime(
                                                _companyScheduledDay,
                                                _companyScheduledTime,
                                                null,
                                              )),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      // ✅ Disponibilidad section (hide for empresa view, employees, and company admins with active tasks)
                      if (!widget.isEmpresaView &&
                          !_isEmployee &&
                          !(!_isOwner &&
                              _isCompanyAdmin &&
                              _companyTaskStatus != null)) ...[
                        if (!(_isOwner && _distributorTaskStatus != null))
                          // availability - only show if distributor doesn't have active task
                          AvailabilityPicker(
                            selectedAvailability:
                                _isEditing
                                    ? _selectedAvailability
                                    : _originalAvailability,
                            onAvailabilitySelected:
                                _isEditing
                                    ? (AvailabilityData? availability) {
                                      setState(() {
                                        _selectedAvailability = availability;
                                      });
                                    }
                                    : null,
                            labelText:
                                _isOwner
                                    ? 'Fecha y Hora de Entrega'
                                    : 'Disponibilidad para entrega',
                            prefixIcon: Icons.calendar_month,
                            isRequired: false,
                          ),
                      ],

                      // ✅ Empresa view OR Company admin with completed task OR Employee with completed task OR Distributor with completed task: Show ONLY reviews (no schedule, no user info)
                      if ((widget.isEmpresaView && widget.taskData != null) ||
                          (!_isOwner &&
                              _isCompanyAdmin &&
                              _companyTaskStatus == 'completado') ||
                          (_isEmployee &&
                              (widget.item.workflowStatus == 'completado' ||
                                  _employeeTaskStatus == 'completado')) ||
                          (_isOwner &&
                              (widget.item.workflowStatus == 'completado' ||
                                  _distributorTaskStatus == 'completado'))) ...[
                        const SizedBox(height: 20),
                        // Reviews section only
                        const Text(
                          'Calificaciones',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Load reviews dynamically for both empresa and company admin
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadReviews(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF2D8A8A),
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Error al cargar calificaciones',
                                  style: TextStyle(color: Colors.red),
                                ),
                              );
                            }

                            final reviews = snapshot.data ?? [];

                            if (reviews.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'No hay calificaciones disponibles',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }

                            return Column(
                              children:
                                  reviews.map((review) {
                                    // Get sender info
                                    final senderName =
                                        review['sender']?['names'] ?? 'Usuario';
                                    final senderRole =
                                        review['sender']?['role'] ?? 'user';
                                    final senderId =
                                        review['sender']?['idUser']?.toString();
                                    final createdAt =
                                        review['created_at'] != null
                                            ? DateTime.parse(
                                              review['created_at'],
                                            ).toString().substring(0, 10)
                                            : '';

                                    // ✅ Get contextual label (Entregado por / Recibido por)
                                    final contextualLabel =
                                        _getContextualRoleLabel(review);

                                    return FutureBuilder<Multimedia?>(
                                      future:
                                          senderId != null
                                              ? _loadReviewerAvatar(
                                                senderId,
                                                senderRole,
                                              )
                                              : Future.value(null),
                                      builder: (context, avatarSnapshot) {
                                        final avatarUrl =
                                            avatarSnapshot.data?.url;

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Avatar
                                                  CircleAvatar(
                                                    radius: 24,
                                                    backgroundColor:
                                                        const Color(0xFF2D8A8A),
                                                    backgroundImage:
                                                        avatarUrl != null
                                                            ? CachedNetworkImageProvider(
                                                              avatarUrl,
                                                            )
                                                            : null,
                                                    child:
                                                        avatarUrl == null
                                                            ? Text(
                                                              senderName
                                                                      .isNotEmpty
                                                                  ? senderName[0]
                                                                      .toUpperCase()
                                                                  : 'U',
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            )
                                                            : null,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Name and contextual role
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          contextualLabel,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Text(
                                                          senderName,
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                Colors.black87,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // Date and stars
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        createdAt,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[600],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: List.generate(
                                                          5,
                                                          (index) => Icon(
                                                            index <
                                                                    (review['starID']
                                                                            as int? ??
                                                                        0)
                                                                ? Icons.star
                                                                : Icons
                                                                    .star_border,
                                                            color: Colors.amber,
                                                            size: 20,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (review['comment'] != null &&
                                                  (review['comment'] as String)
                                                      .isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                Text(
                                                  review['comment'],
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  }).toList(),
                            );
                          },
                        ),
                        // Add completion message for both empresa view and company admin
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isEmployee
                                    ? 'Tarea completada'
                                    : (_isOwner
                                        ? 'Artículo entregado'
                                        : 'Artículo Recibido'),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ✅ Employee action button - Confirmar llegada (placed right after schedule)
                      if (_isEmployee &&
                          _employeeTaskId != null &&
                          (_employeeTaskStatus == 'en_proceso' ||
                              _employeeTaskStatus ==
                                  'esperando_confirmacion_empleado')) ...[
                        const SizedBox(height: 20),
                        if (_employeeTaskStatus ==
                            'esperando_confirmacion_empleado') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'El distribuidor confirmó la entrega. Confirma que recibiste el objeto.',
                                    style: TextStyle(
                                      color: Colors.green.shade900,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        MyButton(
                          onTap: _showConfirmArrivalDialog,
                          text:
                              _employeeTaskStatus ==
                                      'esperando_confirmacion_empleado'
                                  ? 'Confirmar recepción'
                                  : 'Confirmar llegada',
                          color: Colors.amber,
                        ),
                      ],

                      // ✅ Distributor action button - Confirmar entrega (for article owner)
                      if (_isOwner &&
                          _distributorTaskId != null &&
                          (_distributorTaskStatus == 'en_proceso' ||
                              _distributorTaskStatus ==
                                  'esperando_confirmacion_distribuidor')) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                _distributorTaskStatus ==
                                        'esperando_confirmacion_distribuidor'
                                    ? Colors.green.shade50
                                    : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  _distributorTaskStatus ==
                                          'esperando_confirmacion_distribuidor'
                                      ? Colors.green.shade300
                                      : Colors.amber.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _distributorTaskStatus ==
                                        'esperando_confirmacion_distribuidor'
                                    ? Icons.check_circle_outline
                                    : Icons.info_outline,
                                color:
                                    _distributorTaskStatus ==
                                            'esperando_confirmacion_distribuidor'
                                        ? Colors.green.shade700
                                        : Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _distributorTaskStatus ==
                                          'esperando_confirmacion_distribuidor'
                                      ? 'El empleado confirmó la entrega. Confirma que entregaste el objeto.'
                                      : 'En proceso: Confirma cuando entregues el objeto',
                                  style: TextStyle(
                                    color:
                                        _distributorTaskStatus ==
                                                'esperando_confirmacion_distribuidor'
                                            ? Colors.green.shade900
                                            : Colors.amber.shade900,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        MyButton(
                          onTap: _showConfirmDeliveryDialog,
                          text: 'Confirmar entrega',
                          color: const Color(0xFF2D8A8A),
                        ),
                      ],

                      // User info section (only in view mode, hide for empresa view, employees with completed tasks, and company admin with completed tasks)
                      if (!_isEditing &&
                          !_isOwner &&
                          !widget.isEmpresaView &&
                          !(_isEmployee &&
                              (widget.item.workflowStatus == 'completado' ||
                                  _employeeTaskStatus == 'completado')) &&
                          !(_isCompanyAdmin &&
                              _companyTaskStatus == 'completado')) ...[
                        const SizedBox(height: 20),
                        const Text(
                          'Información del usuario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D8A8A).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF2D8A8A).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    color: Color(0xFF2D8A8A),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.item.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.email,
                                    color: Color(0xFF2D8A8A),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      widget.item.userEmail,
                                      style: const TextStyle(
                                        color: Color(0xFF2D8A8A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ✅ Pending requests section (only for owner)
                      if (_isOwner &&
                          !_isEditing &&
                          _pendingRequests.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Solicitudes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D8A8A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tienes ${_pendingRequests.length} ${_pendingRequests.length == 1 ? 'solicitud pendiente' : 'solicitudes pendientes'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._pendingRequests.map(
                          (request) => _buildRequestCard(request),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Action buttons
                      if (_isOwner) ...[
                        if (_isEditing)
                          Row(
                            children: [
                              Expanded(
                                child:
                                    _isSubmitting
                                        ? Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D8A8A),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Guardando...',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        : MyButton(
                                          onTap: _saveChanges,
                                          text: 'Guardar Cambios',
                                          color: Color(0xFF2D8A8A),
                                        ),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              // ✅ Hide edit/delete when there are approved requests OR task is in progress/completed
                              if (_hasApprovedRequests ||
                                  (_distributorTaskStatus != null &&
                                      (_distributorTaskStatus == 'completado' ||
                                          _distributorTaskStatus ==
                                              'en_proceso' ||
                                          _distributorTaskStatus ==
                                              'sin_asignar' ||
                                          _distributorTaskStatus ==
                                              'asignado' ||
                                          _distributorTaskStatus ==
                                              'esperando_confirmacion_distribuidor' ||
                                          _distributorTaskStatus ==
                                              'esperando_confirmacion_empleado'))) ...[
                                // Show lock message for approved requests or in-process tasks (not completed)
                                if (_hasApprovedRequests ||
                                    _distributorTaskStatus != 'completado')
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.lock,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _hasApprovedRequests
                                                ? 'No puedes editar o eliminar este artículo porque una empresa ha solicitado recogerlo'
                                                : 'No puedes editar o eliminar este artículo mientras está en proceso',
                                            style: TextStyle(
                                              color: Colors.orange.shade900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ] else ...[
                                MyButton(
                                  onTap: () async {
                                    // ✅ Refrescar categorías bloqueadas antes de entrar en modo edición
                                    await _refreshDisabledCategories();
                                    setState(() {
                                      _isEditing = true;
                                    });
                                  },
                                  text: 'Editar Artículo',
                                  color: Color(0xFF2D8A8A),
                                ),
                                const SizedBox(height: 12),
                                MyButton(
                                  onTap: _isSubmitting ? null : _deleteArticle,
                                  text: 'Eliminar Artículo',
                                  color: Colors.grey,
                                ),
                              ],
                            ],
                          ),
                      ],

                      // ✅ Action buttons for admin-empresa (non-owner, hide for empresa view)
                      if (!_isOwner &&
                          _isCompanyAdmin &&
                          !widget.isEmpresaView) ...[
                        if (_isLoadingRequest)
                          const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2D8A8A),
                            ),
                          )
                        else if (_existingRequest == null)
                          // Show "Solicitar Artículo" button
                          MyButton(
                            onTap: _sendRequestToDistributor,
                            text: 'Solicitar Artículo',
                            color: const Color(0xFF2D8A8A),
                          )
                        else if (_existingRequest!.status == 'pendiente')
                          // Show "Solicitud Pendiente" button (disabled)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pending, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text(
                                  'Solicitud Pendiente',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_companyTaskStatus == 'en_proceso' ||
                            _companyTaskStatus ==
                                'esperando_confirmacion_empleado' ||
                            _companyTaskStatus ==
                                'esperando_confirmacion_distribuidor')
                          // Show "En Proceso" indicator (amber, non-clickable)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.timelapse,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _companyTaskStatus ==
                                          'esperando_confirmacion_empleado'
                                      ? 'Esperando Confirmación del Empleado'
                                      : _companyTaskStatus ==
                                          'esperando_confirmacion_distribuidor'
                                      ? 'Esperando Confirmación del Distribuidor'
                                      : 'En Proceso',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (_existingRequest!.status == 'aprobado' &&
                            (_companyTaskStatus == null ||
                                _companyTaskStatus == 'sin_asignar'))
                          // Show "Asignar Empleado" button (only when no task yet or task not assigned)
                          MyButton(
                            onTap: () {
                              // ✅ Show employee assignment dialog
                              _showAssignEmployeeDialog(_existingRequest!);
                            },
                            text: 'Asignar Empleado',
                            color: Colors.green,
                          )
                        else if (_existingRequest!.status == 'rechazado')
                          // Show "Solicitud Rechazada" message
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text(
                                  'Solicitud Rechazada',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}
