import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:reciclaje_app/components/my_textfield.dart';
import 'package:reciclaje_app/database/employee_database.dart';
import 'package:reciclaje_app/database/media_database.dart';
import 'package:reciclaje_app/model/multimedia.dart';
import 'package:reciclaje_app/services/email_templates.dart';
import 'package:reciclaje_app/services/smtp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeesScreen extends StatefulWidget {
  final int companyId;

  const EmployeesScreen({super.key, required this.companyId});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final EmployeeDatabase _employeeDb = EmployeeDatabase();
  final MediaDatabase _mediaDb = MediaDatabase();
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String _selectedFilter = 'todos'; // 'todos', 'calificación', 'estado'
  String _selectedSort = 'nombre'; // 'nombre', 'objetos', 'rating'
  
  // Pagination state
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  bool _isLoadingMore = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData) {
        _loadMoreEmployees();
      }
    }
  }

  Future<void> _loadMoreEmployees() async {
    if (_isLoadingMore || !_hasMoreData) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      _currentPage++;
      _isLoadingMore = false;
    });
  }

  Future<void> _refreshEmployees() async {
    setState(() {
      _currentPage = 1;
      _hasMoreData = true;
    });
  }

  /// Load employee statistics (completed tasks and rating)
  Future<Map<String, dynamic>> _loadEmployeeStats(int employeeId, int userId) async {
    try {
      // Get completed tasks count
      final tasks = await Supabase.instance.client
          .from('tasks')
          .select('idTask')
          .eq('employeeID', employeeId)
          .eq('workflowStatus', 'completado')
          .eq('state', 1);
      
      final completedCount = tasks.length;
      
      // Get employee rating from reviews
      final reviews = await Supabase.instance.client
          .from('reviews')
          .select('starID')
          .eq('receiverID', userId)
          .eq('state', 1);
      
      double rating = 0.0;
      int reviewCount = reviews.length;
      
      if (reviewCount > 0) {
        int totalStars = 0;
        for (var review in reviews) {
          totalStars += (review['starID'] as int? ?? 0);
        }
        rating = totalStars / reviewCount;
      }
      
      return {
        'completedTasks': completedCount,
        'rating': rating,
        'reviewCount': reviewCount,
      };
    } catch (e) {
      print('❌ Error loading employee stats: $e');
      return {
        'completedTasks': 0,
        'rating': 0.0,
        'reviewCount': 0,
      };
    }
  }

  /// Load employee avatar with role-based path (matching employee_profile_screen.dart)
  Future<Multimedia?> _loadEmployeeAvatar(int userId, String userRole) async {
    try {
      // ✅ Try new path first (with role)
      String avatarPattern = 'users/$userRole/$userId/avatars/';
      Multimedia? avatar = await _mediaDb.getMainPhotoByPattern(avatarPattern);
      
      // ✅ If not found, try old path (without role) for backward compatibility
      if (avatar == null) {
        avatarPattern = 'users/$userId/avatars/';
        avatar = await _mediaDb.getMainPhotoByPattern(avatarPattern);
      }
      
      return avatar;
    } catch (e) {
      print('❌ Error loading employee avatar: $e');
      return null;
    }
  }

  String _generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%';
    final random = Random.secure();
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  /// Determine email provider based on domain
  String _getEmailProvider(String email) {
    final domain = email.toLowerCase().split('@').last;
    if (domain == 'gmail.com') {
      return 'gmail';
    } else if (domain == 'outlook.com' || domain == 'hotmail.com') {
      return 'outlook';
    }
    return 'unknown';
  }

  Future<void> _createEmployee(String name, String email, BuildContext dialogContext) async {
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Validate email
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese un correo válido')),
      );
      return;
    }

    try {
      // Check if email already exists
      final existingEmployee = await _employeeDb.getEmployeeByEmail(email);
      if (existingEmployee != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ya existe un empleado con ese correo')),
        );
        return;
      }

      // Generate temporary password
      final tempPassword = _generateTemporaryPassword();

      // Close the create dialog first
      Navigator.pop(dialogContext);

      // Create employee (creates user + employee record)
      await _employeeDb.createEmployee(
        names: name,
        email: email,
        companyId: widget.companyId,
        temporaryPassword: tempPassword,
      );

      // Send email with temporary password
      print('🔄 Starting email send process for: $email');
      
      // Detect email provider
      final provider = _getEmailProvider(email);
      print('📧 Detected email provider: $provider');
      print('📤 Sending via Gmail SMTP (can send to any provider)');
      
      // Use Gmail SMTP to send to all email providers
      // Gmail can send to Gmail, Outlook, Hotmail, and any other email
      final emailSent = await sendMailFromGmail(
        recipientEmail: email,
        recipientName: name,
        subject: 'Bienvenido a Reciclaje App - Credenciales de Acceso',
        htmlBody: EmailTemplates.employeeTemporaryPassword(
          employeeName: name,
          email: email,
          temporaryPassword: tempPassword,
        ),
      );
      
      print('📬 Email send result: ${emailSent ? "SUCCESS" : "FAILED"}');

      if (mounted) {
        // Show success dialog with temporary password
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 10),
                Text('Empleado Creado'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Empleado creado exitosamente.'),
                const SizedBox(height: 8),
                if (emailSent)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email, color: Colors.green.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '✓ Credenciales enviadas a $email',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No se pudo enviar el email. Comparte las credenciales manualmente.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Credenciales de Acceso:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFF2D8A8A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.email, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(email, style: TextStyle(fontSize: 13))),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.lock, size: 16),
                          const SizedBox(width: 8),
                          const Text('Contraseña:', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contraseña Temporal:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          tempPassword,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tempPassword));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Contraseña copiada')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'IMPORTANTE: Comparte estas credenciales con el empleado. Debe cambiar la contraseña en su primer inicio de sesión.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final message = '''
🌿 Reciclaje App - Credenciales de Acceso

Hola! Tu cuenta de empleado ha sido creada.

📧 Correo: $email
🔑 Contraseña: $tempPassword

⚠️ IMPORTANTE: Debes cambiar esta contraseña en tu primer inicio de sesión.

Descarga la app e inicia sesión con estas credenciales.
''';
                  Share.share(message);
                },
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Compartir'),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear empleado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreateEmployeeDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    bool isCreating = false; // Prevent double submission
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF2D8A8A)),
            SizedBox(width: 10),
            Text('Nuevo Empleado'),
          ],
        ),
        content: Form(
          key: dialogFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Nombre completo',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el nombre completo';
                    }
                    if (value.trim().length < 3) {
                      return 'El nombre debe tener al menos 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: emailController,
                  decoration: InputDecoration(
                    hintText: 'Correo electrónico',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor ingresa el correo electrónico';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Ingresa un correo válido';
                    }
                    final domain = value.toLowerCase().split('@').last;
                    if (domain != 'gmail.com' && domain != 'outlook.com' && domain != 'hotmail.com') {
                      return 'Solo se permiten correos de Gmail, Outlook o Hotmail';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se generará una contraseña temporal automáticamente y se enviará al correo',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: isCreating ? null : () {
              Navigator.pop(dialogContext);
              nameController.dispose();
              emailController.dispose();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: isCreating ? null : () async {
              if (isCreating) return;
              
              // Validate form
              if (!dialogFormKey.currentState!.validate()) {
                return;
              }
              
              setState(() => isCreating = true);
              
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              
              await _createEmployee(name, email, dialogContext);
              
              // Dispose controllers after navigation completes
              nameController.dispose();
              emailController.dispose();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D8A8A)),
            child: isCreating 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Crear'),
          ),
        ],
      )
        ),
    );
  }

  Future<void> _deleteEmployee(Map<String, dynamic> employeeData) async {
    final userName = employeeData['user']['names'] as String?;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de desactivar al empleado "$userName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final userId = employeeData['user']['idUser'] as int;
        await _employeeDb.deleteEmployee(userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Empleado desactivado')),
          );
        }
      } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Empleados',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  // IconButton(
                  //   icon: const Icon(Icons.notifications_outlined, size: 28),
                  //   onPressed: () {
                  //     // TODO: Navigate to notifications
                  //   },
                  // ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF5F7F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            // Filter chips
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            //   child: SingleChildScrollView(
            //     scrollDirection: Axis.horizontal,
            //     child: Row(
            //       children: [
            //         _buildFilterChip(Icons.star, 'calificación', _selectedFilter == 'calificación'),
            //         const SizedBox(width: 8),
            //         _buildFilterChip(Icons.check_circle, 'Estado', _selectedFilter == 'estado'),
            //         const SizedBox(width: 8),
            //         _buildFilterChip(Icons.sort, 'Archivados', _selectedFilter == 'archivados'),
            //       ],
            //     ),
            //   ),
            // ),
            
            // Employee list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _employeeDb.getEmployeesByCompany(widget.companyId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final employees = snapshot.data ?? [];
                  
                  // Filter employees by search query
                  final filteredEmployees = employees.where((emp) {
                    if (_searchQuery.isEmpty) return true;
                    final userName = (emp['user']['names'] as String?)?.toLowerCase() ?? '';
                    final userEmail = (emp['user']['email'] as String?)?.toLowerCase() ?? '';
                    return userName.contains(_searchQuery) || userEmail.contains(_searchQuery);
                  }).toList();

                  if (filteredEmployees.isEmpty && _searchQuery.isNotEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron empleados',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  if (employees.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No hay empleados registrados',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showCreateEmployeeDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Agregar Empleado'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D8A8A),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // ✅ Apply pagination
                  final totalToShow = _currentPage * _itemsPerPage;
                  final paginatedEmployees = filteredEmployees.take(totalToShow).toList();
                  final hasMore = filteredEmployees.length > paginatedEmployees.length;
                  
                  // Update hasMoreData flag
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _hasMoreData != hasMore) {
                      setState(() {
                        _hasMoreData = hasMore;
                      });
                    }
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total count
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text(
                          'Total ${filteredEmployees.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      
                      // Employee cards with RefreshIndicator
                      Expanded(
                        child: RefreshIndicator(
                          color: const Color(0xFF2D8A8A),
                          onRefresh: _refreshEmployees,
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: paginatedEmployees.length + (hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == paginatedEmployees.length) {
                                // Loading indicator at bottom
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  alignment: Alignment.center,
                                  child: const Column(
                                    children: [
                                      CircularProgressIndicator(
                                        color: Color(0xFF2D8A8A),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Cargando empleados...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              
                              final employeeData = paginatedEmployees[index];
                              return _buildEmployeeCard(employeeData);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateEmployeeDialog,
        backgroundColor: const Color(0xFF2D8A8A),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label, bool isSelected) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: isSelected ? const Color(0xFF2D8A8A) : Colors.grey),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? label.toLowerCase() : 'todos';
        });
      },
      selectedColor: const Color(0xFF2D8A8A).withOpacity(0.2),
      checkmarkColor: const Color(0xFF2D8A8A),
      backgroundColor: const Color(0xFFF5F7F8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2D8A8A) : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employeeData) {
    final user = employeeData['user'];
    final userName = user['names'] as String? ?? 'Sin nombre';
    final userId = user['idUser'] as int;
    final employeeId = employeeData['idEmployee'] as int;
    final userRole = (user['role'] as String?)?.toLowerCase() ?? 'empleado';
    
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadEmployeeStats(employeeId, userId),
      builder: (context, statsSnapshot) {
        final stats = statsSnapshot.data ?? {
          'completedTasks': 0,
          'rating': 0.0,
          'reviewCount': 0,
        };
        
        final completedTasks = stats['completedTasks'] as int;
        final rating = stats['rating'] as double;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () {
              // TODO: Navigate to employee detail
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Profile picture
                  FutureBuilder<Multimedia?>(
                    future: _loadEmployeeAvatar(userId, userRole),
                    builder: (context, avatarSnapshot) {
                      final avatar = avatarSnapshot.data;
                      
                      if (avatar?.url != null) {
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatar!.url!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF2D8A8A),
                              child: const CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                            errorWidget: (context, url, error) => CircleAvatar(
                              radius: 30,
                              backgroundColor: const Color(0xFF2D8A8A),
                              child: Text(
                                userName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      
                      return CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF2D8A8A),
                        child: Text(
                          userName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  
                  // Employee info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedTasks objetos asignados',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : '0',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _deleteEmployee(employeeData),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
