# 📋 SISTEMA DE ASIGNACIÓN DE TAREAS - GUÍA DE IMPLEMENTACIÓN

## 📌 Resumen
Este documento describe el sistema completo de asignación de tareas para empleados en la aplicación de reciclaje.

---

## 🗄️ 1. BASE DE DATOS

### Tabla: `tasks`

**Ubicación del SQL:** `database_setup/create_tasks_table.sql`

**Estructura de la tabla:**
```sql
CREATE TABLE tasks (
  idTask SERIAL PRIMARY KEY,
  employeeID INTEGER NOT NULL REFERENCES employees(idEmployee),
  articleID INTEGER NOT NULL REFERENCES article(idArticle),
  companyID INTEGER NOT NULL REFERENCES company(idCompany),
  assignedBy INTEGER NOT NULL REFERENCES users(idUsers),
  status VARCHAR(20) DEFAULT 'sin_asignar',
  priority VARCHAR(10) DEFAULT 'media',
  assignedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  startDate TIMESTAMP,
  completedDate TIMESTAMP,
  dueDate DATE,
  notes TEXT,
  employeeNotes TEXT,
  estimatedDuration INTEGER,
  actualDuration INTEGER,
  collectionLatitude DOUBLE PRECISION,
  collectionLongitude DOUBLE PRECISION,
  lastUpdate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Estados válidos:**
- `sin_asignar` - Creada pero no asignada aún
- `asignado` - Asignada al empleado
- `en_proceso` - Empleado está trabajando en ella
- `completado` - Tarea completada exitosamente
- `cancelado` - Tarea cancelada

**Prioridades:**
- `baja` - Prioridad baja
- `media` - Prioridad media (por defecto)
- `alta` - Prioridad alta
- `urgente` - Requiere atención inmediata

**Características automáticas:**
- ✅ Actualización automática de `lastUpdate` en cada cambio
- ✅ Actualización automática de `startDate` al cambiar a `en_proceso`
- ✅ Actualización automática de `completedDate` al cambiar a `completado`
- ✅ Cálculo automático de `actualDuration` al completar
- ✅ Row Level Security (RLS) habilitado
- ✅ Índices para optimización de consultas

**Pasos de instalación:**
1. Ir a Supabase → SQL Editor
2. Copiar y ejecutar el contenido de `create_tasks_table.sql`
3. Verificar que la tabla se creó correctamente

---

## 📦 2. MODELOS (Models)

### Task Model
**Archivo:** `lib/model/task.dart`

**Clases:**
1. **`Task`** - Modelo básico de tarea
2. **`TaskDetailed`** - Modelo con información detallada (joined data)

**Uso:**
```dart
import 'package:reciclaje_app/model/task.dart';

// Crear tarea básica
final task = Task(
  employeeId: 1,
  articleId: 5,
  companyId: 2,
  assignedBy: 10,
  status: 'asignado',
  priority: 'alta',
  notes: 'Recolectar antes del mediodía',
);

// Convertir a Map para Supabase
final taskMap = task.toMap();

// Crear desde Map
final taskFromDb = Task.fromMap(dbResponse);
```

---

## 💾 3. BASE DE DATOS SERVICE

### TaskDatabase
**Archivo:** `lib/database/task_database.dart`

**Métodos principales:**

#### CREATE
- `createTask(Task task)` - Crear nueva tarea
- `createBulkTasks(List<Task> tasks)` - Crear múltiples tareas

#### READ
- `getTasksByCompany(int companyId)` - Todas las tareas de una empresa
- `getTasksByEmployee(int employeeId)` - Tareas de un empleado
- `getTasksByStatus(int companyId, String status)` - Filtrar por estado
- `getDetailedTasksByCompany(int companyId)` - Tareas con info detallada
- `getDetailedTasksByEmployee(int employeeId)` - Tareas detalladas del empleado
- `getTaskById(int taskId)` - Una tarea específica
- `getOverdueTasks(int companyId)` - Tareas vencidas
- `getPendingTasksByEmployee(int employeeId)` - Tareas pendientes
- `getCompletedTasksByEmployee(int employeeId)` - Tareas completadas

#### UPDATE
- `updateTaskStatus(int taskId, String newStatus)` - Cambiar estado
- `updateEmployeeNotes(int taskId, String notes)` - Actualizar notas del empleado
- `updateCollectionLocation(int taskId, double lat, double lng)` - Ubicación de recolección
- `updateTask(int taskId, Map<String, dynamic> updates)` - Actualización general
- `reassignTask(int taskId, int newEmployeeId)` - Reasignar a otro empleado

#### DELETE
- `deleteTask(int taskId)` - Eliminar tarea

#### ESTADÍSTICAS
- `getEmployeeTaskStats(int employeeId)` - Estadísticas del empleado
- `getTaskCountByStatus(int companyId)` - Conteo por estado

**Ejemplo de uso:**
```dart
final _taskDatabase = TaskDatabase();

// Crear tarea
final newTask = Task(
  employeeId: 1,
  articleId: 5,
  companyId: 2,
  assignedBy: 10,
  status: 'asignado',
  priority: 'alta',
);
final result = await _taskDatabase.createTask(newTask);

// Obtener tareas de empresa
final tasks = await _taskDatabase.getTasksByCompany(2);

// Cambiar estado
await _taskDatabase.updateTaskStatus(taskId, 'en_proceso');

// Obtener estadísticas
final stats = await _taskDatabase.getEmployeeTaskStats(employeeId);
```

---

## 🖥️ 4. PANTALLA DE ASIGNACIÓN

### TaskAssignmentScreen
**Archivo:** `lib/screen/empresa/task_assignment_screen.dart`

**Características:**
- ✅ Mapa interactivo con artículos publicados
- ✅ Marcadores de color (verde = disponible, naranja = asignado)
- ✅ Panel lateral de asignación
- ✅ Selector de empleados
- ✅ Selector de prioridad (baja, media, alta, urgente)
- ✅ Selector de fecha límite
- ✅ Campo de notas para el empleado
- ✅ Filtros: disponibles, asignados, todos
- ✅ Barra de estadísticas en tiempo real
- ✅ Actualización automática después de asignar

**Flujo de uso:**
1. Admin-empresa abre la pantalla
2. Ve mapa con todos los artículos publicados
3. Hace clic en un artículo (marcador verde/naranja)
4. Selecciona un empleado del dropdown
5. Elige prioridad y fecha límite (opcional)
6. Agrega notas para el empleado
7. Hace clic en "Asignar Tarea"
8. Sistema crea tarea en Supabase
9. Actualiza mapa y estadísticas

**Agregar a navegación:**
```dart
// En company_navigation_screens.dart o el menú de empresa
ListTile(
  leading: Icon(Icons.assignment),
  title: Text('Asignar Tareas'),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskAssignmentScreen(),
      ),
    );
  },
),
```

---

## 👷 5. PANTALLA DE EMPLEADO

### EmployeeTasksScreen
**Archivo:** `lib/screen/employee/employee_tasks_screen.dart`

**Necesita actualización para mostrar tareas reales:**

```dart
// Reemplazar la carga de datos de ejemplo con:
final _taskDatabase = TaskDatabase();

Future<void> _loadTasks() async {
  final employeeData = await _employeeDatabase.getEmployeeByUserId(_currentUserId!);
  if (employeeData != null) {
    final tasks = await _taskDatabase.getDetailedTasksByEmployee(
      employeeData['idEmployee']
    );
    
    setState(() {
      _allTasks = tasks;
      _filterTasks();
    });
  }
}

void _filterTasks() {
  switch (_selectedFilter) {
    case 'pending':
      _filteredTasks = _allTasks.where((t) => 
        t.status == 'asignado' || t.status == 'en_proceso'
      ).toList();
      break;
    case 'completed':
      _filteredTasks = _allTasks.where((t) => 
        t.status == 'completado'
      ).toList();
      break;
    default:
      _filteredTasks = _allTasks;
  }
}
```

---

## 🔄 6. FLUJO COMPLETO DEL SISTEMA

### Ciclo de vida de una tarea:

```
1. CREACIÓN (Admin-empresa)
   ↓
   TaskAssignmentScreen
   - Selecciona artículo en mapa
   - Selecciona empleado
   - Define prioridad y fecha límite
   - Agrega notas
   - Crea tarea → status: 'asignado'

2. RECEPCIÓN (Empleado)
   ↓
   EmployeeTasksScreen
   - Ve tarea en lista "Pendientes"
   - Lee detalles: artículo, ubicación, notas del admin
   - Puede ver en mapa

3. INICIO (Empleado)
   ↓
   - Empleado inicia tarea
   - status: 'asignado' → 'en_proceso'
   - startDate se establece automáticamente

4. RECOLECCIÓN (Empleado)
   ↓
   - Va a ubicación del artículo
   - Puede reportar su ubicación
   - Puede agregar notas (employeeNotes)

5. COMPLETADO (Empleado)
   ↓
   - Marca tarea como completada
   - status: 'en_proceso' → 'completado'
   - completedDate se establece automáticamente
   - actualDuration se calcula automáticamente

6. SEGUIMIENTO (Admin-empresa)
   ↓
   - Ve estadísticas en dashboard
   - Puede ver historial de tareas completadas
   - Puede reasignar tareas si es necesario
```

---

## 📊 7. ESTADÍSTICAS Y REPORTES

### Datos disponibles:

**Por Empleado:**
- Total de tareas asignadas
- Tareas pendientes
- Tareas en proceso
- Tareas completadas
- Tiempo promedio de completado

**Por Empresa:**
- Artículos disponibles vs asignados
- Tareas por estado
- Tareas vencidas
- Empleados más activos

**Funciones SQL disponibles:**
```sql
-- Estadísticas de empleado
SELECT * FROM get_employee_task_stats(employee_id);

-- Tareas vencidas
SELECT * FROM get_overdue_tasks(company_id);

-- Vista detallada
SELECT * FROM tasks_detailed WHERE idcompany = company_id;
```

---

## ✅ 8. CHECKLIST DE IMPLEMENTACIÓN

### Paso 1: Base de Datos
- [ ] Ejecutar `create_tasks_table.sql` en Supabase
- [ ] Verificar que la tabla existe
- [ ] Verificar que los triggers funcionan
- [ ] Verificar RLS policies

### Paso 2: Backend (Ya completado)
- [✅] Modelo `Task` creado
- [✅] Modelo `TaskDetailed` creado
- [✅] `TaskDatabase` con todos los métodos
- [✅] Importaciones correctas

### Paso 3: Interfaz de Empresa
- [✅] `TaskAssignmentScreen` creada
- [ ] Agregar navegación en menú de empresa
- [ ] Probar asignación de tareas
- [ ] Verificar que se guardan en Supabase

### Paso 4: Interfaz de Empleado
- [✅] `EmployeeTasksScreen` estructura base
- [ ] Actualizar para cargar tareas reales desde Supabase
- [ ] Agregar funcionalidad de cambio de estado
- [ ] Agregar ubicación de recolección
- [ ] Agregar notas del empleado

### Paso 5: Testing
- [ ] Crear tarea desde admin-empresa
- [ ] Verificar que empleado la ve
- [ ] Cambiar estado de tarea
- [ ] Completar tarea
- [ ] Verificar estadísticas

---

## 🚀 9. PRÓXIMOS PASOS SUGERIDOS

### Mejoras prioritarias:
1. **Notificaciones Push**
   - Notificar al empleado cuando se le asigna una tarea
   - Recordatorios de tareas próximas a vencer

2. **Tracking GPS**
   - Mostrar ruta del empleado en tiempo real
   - Verificar que el empleado llegó a la ubicación

3. **Fotos de Evidencia**
   - Empleado toma foto al recolectar
   - Admin puede ver evidencia de recolección

4. **Historial y Reportes**
   - Dashboard con gráficos
   - Exportar reportes en PDF
   - Análisis de rendimiento

5. **Optimización de Rutas**
   - Asignar múltiples tareas en secuencia
   - Sugerir ruta óptima al empleado

---

## 🐛 10. TROUBLESHOOTING

### Error: "No se puede crear tarea"
- Verificar que la tabla `tasks` existe
- Verificar RLS policies
- Verificar que companyId, employeeId, articleId existen

### Error: "No se cargan las tareas"
- Verificar conexión a Supabase
- Verificar que el empleado tiene tareas asignadas
- Revisar console logs

### Tareas no aparecen en empleado
- Verificar que employeeId es correcto
- Verificar RLS policy para empleados
- Verificar que status != 'cancelado'

---

## 📞 11. SOPORTE

Para más ayuda:
1. Revisar logs en consola
2. Verificar Supabase Dashboard
3. Probar queries SQL directamente
4. Revisar este documento

---

**Última actualización:** Octubre 31, 2025
**Versión:** 1.0.0
