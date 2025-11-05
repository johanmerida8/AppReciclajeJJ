import 'package:reciclaje_app/model/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskDatabase {
  final _supabase = Supabase.instance.client;

  // ============================================================================
  // CREATE - Crear nueva tarea
  // ============================================================================
  
  Future<Task?> createTask(Task task) async {
    try {
      final response = await _supabase
          .from('tasks')
          .insert(task.toMap())
          .select()
          .single();
      
      return Task.fromMap(response);
    } catch (e) {
      print('❌ Error creating task: $e');
      return null;
    }
  }

  // ============================================================================
  // READ - Consultas de tareas
  // ============================================================================
  
  /// Obtener todas las tareas de una empresa
  Future<List<Task>> getTasksByCompany(int companyId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('companyID', companyId)
          .order('assignedDate', ascending: false);
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching tasks by company: $e');
      return [];
    }
  }

  /// Obtener tareas de un empleado específico
  Future<List<Task>> getTasksByEmployee(int employeeId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('employeeID', employeeId)
          .order('assignedDate', ascending: false);
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching tasks by employee: $e');
      return [];
    }
  }

  /// Obtener tareas filtradas por estado
  Future<List<Task>> getTasksByStatus(int companyId, String status) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('companyID', companyId)
          .eq('status', status)
          .order('assignedDate', ascending: false);
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching tasks by status: $e');
      return [];
    }
  }

  /// Obtener tareas con información detallada (usando la vista tasks_detailed)
  Future<List<TaskDetailed>> getDetailedTasksByCompany(int companyId) async {
    try {
      final response = await _supabase
          .from('tasks_detailed')
          .select()
          .eq('idcompany', companyId)
          .order('assigneddate', ascending: false);
      
      return (response as List)
          .map((task) => TaskDetailed.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching detailed tasks: $e');
      return [];
    }
  }

  /// Obtener tareas detalladas de un empleado
  Future<List<TaskDetailed>> getDetailedTasksByEmployee(int employeeId) async {
    try {
      final response = await _supabase
          .from('tasks_detailed')
          .select()
          .eq('idemployee', employeeId)
          .order('assigneddate', ascending: false);
      
      return (response as List)
          .map((task) => TaskDetailed.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching detailed employee tasks: $e');
      return [];
    }
  }

  /// Obtener una tarea por ID
  Future<Task?> getTaskById(int taskId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('idTask', taskId)
          .single();
      
      return Task.fromMap(response);
    } catch (e) {
      print('❌ Error fetching task by ID: $e');
      return null;
    }
  }

  /// Obtener tareas vencidas de una empresa
  Future<List<TaskDetailed>> getOverdueTasks(int companyId) async {
    try {
      final response = await _supabase
          .rpc('get_overdue_tasks', params: {'comp_id': companyId});
      
      return (response as List)
          .map((task) => TaskDetailed.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching overdue tasks: $e');
      return [];
    }
  }

  // ============================================================================
  // UPDATE - Actualizar tareas
  // ============================================================================
  
  /// Actualizar el estado de una tarea
  Future<bool> updateTaskStatus(int taskId, String newStatus) async {
    try {
      await _supabase
          .from('tasks')
          .update({'status': newStatus})
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error updating task status: $e');
      return false;
    }
  }

  /// Actualizar notas del empleado
  Future<bool> updateEmployeeNotes(int taskId, String notes) async {
    try {
      await _supabase
          .from('tasks')
          .update({'employeeNotes': notes})
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error updating employee notes: $e');
      return false;
    }
  }

  /// Actualizar ubicación de recolección
  Future<bool> updateCollectionLocation(
    int taskId,
    double latitude,
    double longitude,
  ) async {
    try {
      await _supabase
          .from('tasks')
          .update({
            'collectionLatitude': latitude,
            'collectionLongitude': longitude,
          })
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error updating collection location: $e');
      return false;
    }
  }

  /// Actualizar tarea completa
  Future<bool> updateTask(int taskId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('tasks')
          .update(updates)
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error updating task: $e');
      return false;
    }
  }

  /// Reasignar tarea a otro empleado
  Future<bool> reassignTask(int taskId, int newEmployeeId) async {
    try {
      await _supabase
          .from('tasks')
          .update({
            'employeeID': newEmployeeId,
            'status': 'asignado',
          })
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error reassigning task: $e');
      return false;
    }
  }

  // ============================================================================
  // DELETE - Eliminar tarea
  // ============================================================================
  
  Future<bool> deleteTask(int taskId) async {
    try {
      await _supabase
          .from('tasks')
          .delete()
          .eq('idTask', taskId);
      
      return true;
    } catch (e) {
      print('❌ Error deleting task: $e');
      return false;
    }
  }

  // ============================================================================
  // ESTADÍSTICAS
  // ============================================================================
  
  /// Obtener estadísticas de tareas de un empleado
  Future<Map<String, dynamic>?> getEmployeeTaskStats(int employeeId) async {
    try {
      final response = await _supabase
          .rpc('get_employee_task_stats', params: {'emp_id': employeeId})
          .single();
      
      return response;
    } catch (e) {
      print('❌ Error fetching employee task stats: $e');
      return null;
    }
  }

  /// Obtener conteo de tareas por estado para una empresa
  Future<Map<String, int>> getTaskCountByStatus(int companyId) async {
    try {
      final tasks = await getTasksByCompany(companyId);
      
      Map<String, int> counts = {
        'sin_asignar': 0,
        'asignado': 0,
        'en_proceso': 0,
        'completado': 0,
        'cancelado': 0,
      };
      
      for (var task in tasks) {
        if (task.status != null) {
          counts[task.status!] = (counts[task.status!] ?? 0) + 1;
        }
      }
      
      return counts;
    } catch (e) {
      print('❌ Error counting tasks by status: $e');
      return {};
    }
  }

  /// Obtener tareas pendientes (asignadas pero no completadas) de un empleado
  Future<List<Task>> getPendingTasksByEmployee(int employeeId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('employeeID', employeeId)
          .inFilter('status', ['asignado', 'en_proceso'])
          .order('dueDate', ascending: true);
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching pending tasks: $e');
      return [];
    }
  }

  /// Obtener tareas completadas de un empleado
  Future<List<Task>> getCompletedTasksByEmployee(int employeeId) async {
    try {
      final response = await _supabase
          .from('tasks')
          .select()
          .eq('employeeID', employeeId)
          .eq('status', 'completado')
          .order('completedDate', ascending: false);
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error fetching completed tasks: $e');
      return [];
    }
  }

  // ============================================================================
  // ASIGNACIÓN MASIVA
  // ============================================================================
  
  /// Crear múltiples tareas de una vez
  Future<List<Task>> createBulkTasks(List<Task> tasks) async {
    try {
      final response = await _supabase
          .from('tasks')
          .insert(tasks.map((t) => t.toMap()).toList())
          .select();
      
      return (response as List)
          .map((task) => Task.fromMap(task))
          .toList();
    } catch (e) {
      print('❌ Error creating bulk tasks: $e');
      return [];
    }
  }
}
