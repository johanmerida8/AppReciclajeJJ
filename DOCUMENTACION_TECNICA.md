# 📱 Documentación Técnica - App de Reciclaje

## 📋 Índice
1. [Visión General del Proyecto](#visión-general)
2. [Arquitectura del Sistema](#arquitectura)
3. [Módulos Principales](#módulos)
4. [Tecnologías y Servicios](#tecnologías)
5. [Base de Datos](#base-de-datos)
6. [Autenticación y Roles](#autenticación)
7. [Componentes Reutilizables](#componentes)
8. [Validaciones](#validaciones)
9. [Servicios de Mapas](#mapas)
10. [Flujos de Trabajo](#flujos)

---

## 🎯 Visión General del Proyecto

### Descripción
Aplicación móvil Flutter para la gestión de reciclaje colaborativo entre distribuidores, empresas y empleados. Permite publicar, solicitar y recolectar artículos reciclables con geolocalización en tiempo real.

### Objetivo Principal
Facilitar la economía circular mediante una plataforma que conecta a personas que desean donar artículos reciclables con empresas de reciclaje y sus empleados recolectores.

### Plataformas Soportadas
- ✅ Android
- ✅ iOS
- ✅ Web
- ⚠️ Windows/Linux/macOS (parcial)

---

## 🏗️ Arquitectura del Sistema

### Patrón de Arquitectura
**Arquitectura por Capas + MVC Modificado**

```
┌─────────────────────────────────────────┐
│          CAPA DE PRESENTACIÓN           │
│  (Screens, Widgets, Components)         │
├─────────────────────────────────────────┤
│         CAPA DE SERVICIOS               │
│  (Auth, Maps, Location, Email, Cache)   │
├─────────────────────────────────────────┤
│         CAPA DE DATOS                   │
│  (Database, Models)                     │
├─────────────────────────────────────────┤
│         BACKEND (Supabase)              │
│  (PostgreSQL, Auth, Storage, RLS)       │
└─────────────────────────────────────────┘
```

### Stack Tecnológico Principal

#### Frontend
- **Framework**: Flutter 3.7.2
- **Lenguaje**: Dart
- **UI**: Material Design 3
- **Navegación**: Custom Navigation Bars

#### Backend
- **BaaS**: Supabase
- **Base de Datos**: PostgreSQL (cloud)
- **Autenticación**: Supabase Auth
- **Storage**: Supabase Storage (imágenes/multimedia)
- **Security**: Row Level Security (RLS)

#### Servicios de Mapas
- **Proveedor**: OpenStreetMap (CartoDB)
- **Librería**: flutter_map ^8.2.1
- **Coordenadas**: latlong2 ^0.9.1
- **Geocoding**: geocoding ^4.0.0
- **Location**: location ^7.0.0

---

## 📦 Módulos Principales

### 1. Módulo de Autenticación (auth/)
**Propósito**: Gestión de acceso y seguridad

**Componentes**:
- `auth_service.dart` - Servicio central de autenticación
- `auth_gate.dart` - Control de acceso basado en roles

**Funcionalidades**:
- ✅ Registro con email/contraseña
- ✅ Login con verificación de roles
- ✅ OTP (One-Time Password) via Supabase
- ✅ Recuperación de contraseña (Magic Links)
- ✅ Límites de intentos (rate limiting)
- ✅ Gestión de sesiones
- ✅ Deep linking para reset de contraseña

**Roles del Sistema**:
1. **Administrador** - Control total del sistema
2. **Admin-Empresa** - Gestiona empresa y empleados
3. **Distribuidor** - Publica artículos de reciclaje
4. **Empleado** - Recolecta artículos asignados

**Flujo de Autenticación**:
```dart
Usuario → Login → Verificación de Estado (state=1) 
  → Verificación de Rol → Redirección a Dashboard correspondiente
```

---

### 2. Módulo de Usuarios (Distribuidor)

**Ubicación**: `lib/screen/distribuidor/`

#### Pantallas Principales:
1. **HomeScreen** (`home_screen.dart`)
   - Mapa interactivo con artículos publicados
   - Registro rápido desde mapa (tap en ubicación)
   - Clustering de marcadores dinámico
   - Filtros por estado de workflow
   - Notificaciones de solicitudes pendientes

2. **RegisterRecycleScreen** (`RegisterRecycle_screen.dart`)
   - Formulario de publicación de artículos
   - Galería de fotos (hasta 5 imágenes)
   - Selección de categoría
   - Selector de ubicación en mapa
   - Días y horarios de disponibilidad

3. **ProfileScreen** (`profile_screen.dart`)
   - Información personal
   - Avatar personalizable
   - Estadísticas de artículos
   - Historial de reseñas
   - Configuración de cuenta

4. **NotificationsScreen** (`notifications_screen.dart`)
   - Solicitudes de empresas (pendientes/aprobadas/rechazadas)
   - Filtro de notificaciones leídas (SharedPreferences)
   - Asignación de empleados a solicitudes aprobadas
   - Confirmación de entregas

5. **RankingScreen** (`ranking_screen.dart`)
   - Sistema de puntos (EXP)
   - Podio top 3 (oro, plata, bronce)
   - Lista de rankings hasta posición 100
   - Ciclos mensuales con contador de días
   - Integración con sistema de reseñas

6. **DetailRecycleScreen** (`detail_recycle_screen.dart`)
   - Vista detallada de artículos
   - Galería de imágenes
   - Información del publicador
   - Mapa de ubicación
   - Sistema de reseñas bidireccional
   - Gestión de workflow (distribuidor/empresa/empleado)
   - Confirmación de entregas

**Características Técnicas**:
- ✅ Clustering inteligente de marcadores (zoom dinámico)
- ✅ Navegación entre artículos cercanos (modal Anterior/Siguiente)
- ✅ Cache local con actualización en background
- ✅ Validación de límite de publicaciones (máx. 3 activos)
- ✅ Sistema de puntos por confirmaciones
- ✅ Gestión de estado offline

---

### 3. Módulo de Empresa (Admin-Empresa)

**Ubicación**: `lib/screen/empresa/`

#### Pantallas Principales:
1. **CompanyMapScreen** (`company_map_screen.dart`)
   - Mapa de artículos disponibles (todos los distribuidores)
   - Solicitud de artículos con programación
   - Asignación de empleados a tareas
   - Filtros por estado de workflow
   - Notificaciones de solicitudes aprobadas

2. **EmployeesScreen** (`employees_screen.dart`)
   - Lista de empleados de la empresa
   - Creación de empleados con contraseña temporal
   - Estadísticas por empleado
   - Gestión de tareas asignadas
   - Sistema de calificaciones

3. **CompanyProfileScreen** (`company_profile_screen.dart`)
   - Información de la empresa
   - Logo empresarial
   - Estadísticas de artículos gestionados
   - Empleados registrados

4. **CompanyNotificationsScreen** (`company_notifications_screen.dart`)
   - Solicitudes aprobadas/rechazadas
   - Tareas pendientes de asignación
   - Historial de recolecciones

5. **CompanyRegistrationScreen** (`company_registration_screen.dart`)
   - Registro de nuevas empresas
   - Validación de admin-empresa
   - Proceso de aprobación por administrador

**Workflow de Solicitud**:
```
1. Empresa solicita artículo → Estado: "en_espera"
2. Distribuidor aprueba → Estado: "sin_asignar" + crea Task
3. Empresa asigna empleado → Estado: "en_proceso"
4. Empleado recolecta → Estado: "esperando_confirmacion"
5. Ambos confirman → Estado: "completado" + Puntos
```

---

### 4. Módulo de Empleado

**Ubicación**: `lib/screen/employee/`

#### Pantallas Principales:
1. **EmployeeMapScreen** (`employee_map_screen.dart`)
   - Mapa con tareas asignadas únicamente
   - Navegación a ubicaciones de artículos
   - Confirmación de recolección
   - Estados: asignado, en_proceso, completado

2. **EmployeeTasksScreen** (`employee_tasks_screen.dart`)
   - Lista de tareas pendientes
   - Filtros por estado
   - Detalles de cada recolección
   - Información de contacto del distribuidor

3. **EmployeeProfileScreen** (`employee_profile_screen.dart`)
   - Información personal
   - Empresa asociada
   - Estadísticas de recolecciones
   - Reseñas recibidas

4. **EmployeeNotificationsScreen** (`employee_notifications_screen.dart`)
   - Nuevas tareas asignadas
   - Recordatorios de horarios programados

**Sistema de Empleados**:
- ✅ Vinculación a empresa específica (companyId)
- ✅ Creación con contraseña temporal
- ✅ Primer login activa cuenta Supabase
- ✅ No pueden publicar artículos, solo recolectar

---

### 5. Módulo de Administrador

**Ubicación**: `lib/screen/administrator/`

#### Pantallas Principales:
1. **AdministratorDashboardScreen** (`administrator_dashboard_screen.dart`)
   - Panel de control general
   - Gestión de empresas
   - Gestión de usuarios
   - Estadísticas globales

2. **UserList** (`userList.dart`)
   - Lista de distribuidores registrados
   - Aprobación/rechazo de cuentas
   - Filtros por estado
   - Búsqueda de usuarios

3. **CompanyList** (`companyList.dart`)
   - Empresas pendientes de aprobación
   - Empresas activas
   - Validación de información empresarial

**Permisos Especiales**:
- ✅ Máximo 3 administradores en el sistema
- ✅ Aprobación de empresas (isApproved: 'Pending' → 'Approved')
- ✅ Gestión de estado de usuarios (state: 0 o 1)
- ✅ Acceso a todas las tablas

---

## 🛠️ Tecnologías y Servicios

### Servicios Principales (lib/services/)

#### 1. MapService (`map_service.dart`)
**Funciones**:
- Centrado automático de mapas
- Cálculo de límites (bounds)
- Ajuste de zoom inteligente
- Validación de estado del MapController

**Configuración**:
```dart
static const LatLng cochabambaCenter = LatLng(-17.3895, -66.1568);
static const double closeZoomLevel = 18.0;
static const double farZoomLevel = 11.0;
```

**Restricciones Geográficas**:
- Límites del mapa: Bolivia
- Zoom mínimo: 6.0
- Zoom máximo: 18.0
- Rotación: Deshabilitada

**Proveedor de Tiles**:
```dart
urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png'
subdomains: ['a', 'b', 'c']
```

#### 2. LocationService (`location_service.dart`)
**Funciones**:
- Obtención de ubicación GPS
- Verificación de permisos
- Gestión de servicios de ubicación
- Cache de última ubicación conocida
- Actualización en background

**Permisos Requeridos**:
- Android: ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION
- iOS: NSLocationWhenInUseUsageDescription

**Manejo de Estados**:
```dart
- serviceEnabled: bool (GPS activado)
- hasPermission: bool (permisos otorgados)
- lastKnownLocation: LatLng? (caché)
```

#### 3. MarkerClusterService (`marker_cluster.dart`)
**Funciones**:
- Agrupación de marcadores cercanos
- Cálculo de clusters por nivel de zoom
- Detección de artículos cercanos (300m radio)
- Clustering dinámico

**Algoritmo**:
- Fórmula Haversine para distancias
- Umbral de distancia por zoom
- Agrupación automática

#### 4. CacheService (`cache_service.dart`)
**Funciones**:
- Almacenamiento local de artículos
- Actualización en background
- Reducción de llamadas a API
- SharedPreferences para persistencia

#### 5. WorkflowService (`workflow_service.dart`)
**Funciones**:
- Validación de límite de publicaciones (máx. 3)
- Verificación de artículos activos
- Control de workflow de estados

#### 6. EmailService (`email_templates.dart`)
**Funciones**:
- Templates HTML para correos
- Envío de contraseñas temporales
- Magic links (recuperación de contraseña)
- OTP codes

#### 7. CycleService (`cycle_service.dart`)
**Funciones**:
- Gestión de ciclos de ranking
- Cálculo de días restantes
- Verificación de ciclos activos

---

## 🗄️ Base de Datos

### Esquema de Tablas Principales

#### users
```sql
idUser (PK) - SERIAL
names - VARCHAR
email - VARCHAR UNIQUE
role - VARCHAR ('administrador', 'admin-empresa', 'distribuidor', 'empleado')
state - INTEGER (0=inactivo, 1=activo)
created_at - TIMESTAMP
lastUpdate - TIMESTAMP
```

#### company
```sql
idCompany (PK) - SERIAL
nameCompany - VARCHAR
adminUserID (FK) - INTEGER → users(idUser)
state - INTEGER
isApproved - VARCHAR ('Pending', 'Approved', 'Rejected')
created_at - TIMESTAMP
```

#### employees
```sql
idEmployee (PK) - SERIAL
userId (FK, UNIQUE) - INTEGER → users(idUser)
companyId (FK) - INTEGER → company(idCompany)
temporaryPassword - VARCHAR (nullable)
createdAt - TIMESTAMP
updatedAt - TIMESTAMP
```

#### article
```sql
idArticle (PK) - SERIAL
name - VARCHAR
description - TEXT
address - VARCHAR
lat - DOUBLE PRECISION
lng - DOUBLE PRECISION
categoryID (FK) - INTEGER
userID (FK) - INTEGER → users(idUser)
condition - VARCHAR ('Nuevo', 'Usado - Como nuevo', 'Usado - Buen estado', 'Usado - Aceptable', 'Para reparar')
workflowStatus - VARCHAR ('publicados', 'vencido', 'completado')
state - INTEGER (1=activo)
lastUpdate - TIMESTAMP
```

#### daysAvailable
```sql
idDaysAvailable (PK) - SERIAL
articleID (FK) - INTEGER → article(idArticle)
dayName - VARCHAR
timeStart - TIME
timeEnd - TIME
```

#### multimedia
```sql
idMultimedia (PK) - SERIAL
entityType - VARCHAR ('distribuidor', 'admin-empresa', 'empleado', 'article', 'company')
entityID - INTEGER
fileName - VARCHAR
filePath - VARCHAR
url - TEXT
isMain - BOOLEAN
uploadDate - TIMESTAMP
```

#### request
```sql
idRequest (PK) - SERIAL
companyID (FK) - INTEGER
articleID (FK) - INTEGER
status - VARCHAR ('pendiente', 'aprobado', 'rechazado')
scheduledDay - VARCHAR
scheduledStartTime - TIME
scheduledEndTime - TIME
requestDate - TIMESTAMP
```

#### tasks
```sql
idTask (PK) - SERIAL
employeeID (FK) - INTEGER
companyID (FK) - INTEGER
articleID (FK) - INTEGER
requestID (FK) - INTEGER
assignedBy (FK) - INTEGER → users(idUser)
workflowStatus - VARCHAR ('sin_asignar', 'asignado', 'en_proceso', 'esperando_confirmacion_distribuidor', 'esperando_confirmacion_empleado', 'completado')
assignedDate - TIMESTAMP
```

#### reviews
```sql
idReview (PK) - SERIAL
senderID (FK) - INTEGER → users(idUser)
receiverID (FK) - INTEGER → users(idUser)
starID - INTEGER (1-5)
comment - TEXT
taskID (FK) - INTEGER (nullable)
state - INTEGER (1=activo)
createdAt - TIMESTAMP
```

#### cycle
```sql
idCycle (PK) - SERIAL
name - VARCHAR
startDate - DATE
endDate - DATE
state - INTEGER (1=activo)
```

#### current_ranking2 (VIEW)
```sql
idUser
names
email
position
totalpoints
idCycle
```

#### userPointsLog
```sql
idUserPointsLog (PK) - SERIAL
userID (FK) - INTEGER
taskID (FK) - INTEGER
points - INTEGER
createdAt - TIMESTAMP
```

### Row Level Security (RLS)

**Políticas Implementadas**:
- ✅ Distribuidores solo ven sus artículos
- ✅ Empresas solo ven sus empleados y tareas
- ✅ Empleados solo ven sus tareas asignadas
- ✅ Administradores tienen acceso completo

---

## 🔐 Autenticación y Roles

### Sistema de Roles

#### 1. Distribuidor (Usuario Regular)
**Permisos**:
- ✅ Publicar hasta 3 artículos activos
- ✅ Ver solicitudes de empresas
- ✅ Aprobar/rechazar solicitudes
- ✅ Asignar empleados a entregas
- ✅ Confirmar entregas
- ✅ Recibir/dar reseñas
- ✅ Participar en ranking
- ❌ No puede crear empresas
- ❌ No puede ver artículos de otros

**Navegación**: `NavigationScreens` (5 tabs)
1. Mapa (home)
2. Publicar
3. Ranking
4. Perfil
5. Historial

#### 2. Admin-Empresa
**Permisos**:
- ✅ Gestionar empleados
- ✅ Solicitar artículos
- ✅ Asignar tareas a empleados
- ✅ Ver todas las solicitudes de la empresa
- ✅ Confirmar entregas
- ✅ Ver estadísticas empresariales
- ❌ No puede publicar artículos
- ❌ No participa en ranking personal

**Navegación**: `CompanyNavigationScreens` (4 tabs)
1. Dashboard
2. Mapa
3. Notificaciones
4. Perfil

#### 3. Empleado
**Permisos**:
- ✅ Ver tareas asignadas en mapa
- ✅ Confirmar recolecciones
- ✅ Recibir reseñas
- ❌ No puede publicar artículos
- ❌ No puede solicitar artículos
- ❌ No participa en ranking

**Navegación**: `EmployeeNavigationScreens` (4 tabs)
1. Mapa
2. Tareas
3. Notificaciones
4. Perfil

#### 4. Administrador
**Permisos**:
- ✅ Aprobar empresas
- ✅ Gestionar usuarios
- ✅ Acceso a todas las tablas
- ✅ Ver estadísticas globales
- ❌ Máximo 3 en el sistema

**Navegación**: `AdminNavigationScreens` (3 tabs)
1. Dashboard
2. Usuarios
3. Empresas

### Flujo de Registro

#### Distribuidor:
```
1. Registro (register_screen.dart)
2. Crear cuenta Supabase
3. Insertar en tabla users (role='distribuidor', state=1)
4. Login directo → NavigationScreens
```

#### Admin-Empresa:
```
1. Registro de empresa (company_registration_screen.dart)
2. Crear cuenta Supabase
3. Insertar en users (role='admin-empresa', state=0)
4. Insertar en company (isApproved='Pending')
5. Esperar aprobación de administrador
6. Administrador aprueba → state=1, isApproved='Approved'
7. Login permitido → CompanyNavigationScreens
```

#### Empleado:
```
1. Admin-empresa crea empleado (employees_screen.dart)
2. Insertar en users (role='empleado', state=0, sin Supabase)
3. Insertar en employees (userId, companyId, temporaryPassword)
4. Envío de email con contraseña temporal
5. Primer login del empleado:
   - Verificar temporaryPassword
   - Crear cuenta Supabase
   - Actualizar state=1
   - Limpiar temporaryPassword (NULL)
6. Logins subsecuentes → Supabase normal
```

### Seguridad

#### Validaciones de Contraseña
**Requisitos** (password_validator.dart):
- ✅ Mínimo 8 caracteres
- ✅ Al menos 1 mayúscula (A-Z)
- ✅ Al menos 1 minúscula (a-z)
- ✅ Al menos 1 número (0-9)
- ✅ Al menos 1 carácter especial (!@#$%^&*)

#### Rate Limiting
**Recuperación de contraseña**:
- Cooldown: 15 minutos entre intentos
- Máximo: 3 resets por día
- Implementado en `auth_service.dart`

#### Tokens y Sesiones
- **Access Token**: JWT de Supabase
- **Refresh Token**: Automático
- **Expiración**: Manejada por Supabase
- **Deep Links**: Para password reset

---

## 🧩 Componentes Reutilizables

### Ubicación: `lib/components/`

#### 1. Formularios
- **my_textfield.dart** - Campo de texto estándar
- **my_textformfield.dart** - Campo con validación
- **my_dropdown.dart** - Selector desplegable
- **my_button.dart** - Botón personalizado
- **limit_character_two.dart** - Campo con contador de caracteres

#### 2. Ubicación
- **location_selector.dart** - Selector completo de ubicación
- **location_input.dart** - Campo de dirección
- **location_map_preview.dart** - Vista previa de mapa
- **map_picker_screen.dart** - Pantalla completa de selección

#### 3. Multimedia
- **photo_gallery_widget.dart** - Galería de imágenes
- **photo_validation.dart** - Validación de fotos
- **fullscreen_photo_viewer.dart** - Visor de pantalla completa

#### 4. Artículos
- **category_tags.dart** - Tags de categorías
- **condition_selector.dart** - Selector de condición
- **availability_data.dart** - Días/horarios disponibles
- **schedule_pickup_dialog.dart** - Modal de programación

#### 5. Contraseñas
- **password_validator.dart** - Validador visual de requisitos

#### 6. Administración
- **admin/user_card.dart** - Tarjeta de usuario
- **admin/company_card.dart** - Tarjeta de empresa
- **admin/filter_buttons.dart** - Botones de filtro
- **admin/custom_search_bar.dart** - Barra de búsqueda

### Widgets Especializados (lib/widgets/)

#### map_marker.dart
**Marcadores Predefinidos**:
```dart
static Marker userLocationMarker(LatLng position)
static Marker temporaryMarker(LatLng position)
static Marker articleMarker(RecyclingItem item, Function onTap)
```

#### status_indicator.dart
**Indicadores de Estado**:
- Conexión a internet (WiFi/Sin conexión)
- Estado GPS (GPS OK/GPS OFF)
- Botón de refresco
- Contador de notificaciones
- Integrado en top bar de mapas

#### quick_register_dialog.dart
**Modal de Registro Rápido**:
- Activado al hacer tap en mapa
- Muestra dirección geocodificada
- Opciones: Cancelar / Confirmar y registrar

---

## ✅ Validaciones

### 1. Validación de Formularios

#### Email
```dart
validator: (value) {
  if (value == null || value.isEmpty) return 'El email es requerido';
  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
    return 'Email inválido';
  }
  return null;
}
```

#### Contraseña (password_utils.dart)
```dart
bool isStrongPassword(String password) {
  return password.length >= 8 &&
         password.contains(RegExp(r'[A-Z]')) &&
         password.contains(RegExp(r'[a-z]')) &&
         password.contains(RegExp(r'[0-9]')) &&
         password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
}
```

#### Nombre
- Mínimo: 3 caracteres
- Máximo: 50 caracteres
- Solo letras y espacios

#### Teléfono
- Formato: Internacional o local
- Validación de dígitos

### 2. Validación de Imágenes

#### photo_validation.dart
**Restricciones**:
- Tamaño máximo: 5 MB
- Formatos: JPG, JPEG, PNG
- Dimensiones mínimas: 300x300px
- Ratio de aspecto: 4:3 recomendado

**Cropping**:
- Librería: image_cropper ^7.0.5
- Ratio fijo: 4:3
- Implementado en: Fixed43Cropper.dart

### 3. Validación de Datos

#### Artículos
- Nombre: 5-100 caracteres
- Descripción: 10-500 caracteres
- Al menos 1 foto
- Categoría seleccionada
- Ubicación válida
- Al menos 1 día disponible

#### Empresas
- Nombre: 3-100 caracteres
- Admin válido (admin-empresa)
- Logo opcional

#### Empleados
- Usuario con role='empleado'
- Vinculado a empresa
- Email único
- Contraseña temporal generada

### 4. Validación de Límites

#### Publicaciones
**WorkflowService**:
```dart
Future<bool> canUserPublish() async {
  // Máximo 3 artículos activos
  // Excluye artículos completados
  // Verifica estado activo (state=1)
}
```

#### Administradores
```dart
// Máximo 3 administradores en registro
if (existingAdmins.length >= 3) {
  throw Exception('Máximo de administradores alcanzado');
}
```

---

## 🗺️ Servicios de Mapas

### Configuración

#### Proveedor: OpenStreetMap (CartoDB Voyager)
```dart
TileLayer(
  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
  subdomains: ['a', 'b', 'c'],
)
```

**Ventajas**:
- ✅ Gratuito y sin límites
- ✅ Actualizaciones frecuentes
- ✅ Estilo limpio y moderno
- ✅ Buen rendimiento

### Características Implementadas

#### 1. Clustering Dinámico
**MarkerClusterService**:
- Agrupación automática por zoom
- Umbral de distancia variable
- Contador de artículos por cluster
- Color distintivo (teal)

**Lógica**:
```dart
clusterItems(List<RecyclingItem> items, double zoom) {
  // Umbral aumenta con zoom out
  // Agrupa artículos cercanos
  // Retorna clusters y singles
}
```

#### 2. Navegación entre Artículos
**Modal Anterior/Siguiente**:
- Detecta artículos en radio de 300m
- Botones de navegación
- Contador (ej: "2 de 5")
- Centra mapa en artículo actual
- Cierra automáticamente si único

#### 3. Marcadores Personalizados
**Tipos**:
1. **Usuario** (azul pulsante)
2. **Artículo** (teal con ícono de categoría)
3. **Cluster** (teal con número)
4. **Temporal** (rojo para registro rápido)

**Estados**:
- Normal
- Seleccionado (escala 1.3x)
- Hover (no en móvil)

#### 4. Restricciones Geográficas
```dart
CameraConstraint.contain(
  bounds: LatLngBounds(
    LatLng(-22.9, -69.7), // SW Bolivia
    LatLng(-9.6, -57.4),   // NE Bolivia
  ),
)
```

#### 5. Interacciones
**Deshabilitadas**:
- ❌ Rotación del mapa
- ❌ Tilt/inclinación

**Habilitadas**:
- ✅ Pan (arrastrar)
- ✅ Zoom (pinch/doble tap)
- ✅ Tap en marcadores
- ✅ Tap en mapa (registro rápido)

### Geocoding

#### Dirección → Coordenadas
```dart
List<Location> locations = await locationFromAddress(address);
LatLng position = LatLng(locations.first.latitude, locations.first.longitude);
```

#### Coordenadas → Dirección
```dart
List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
String address = '${placemark.street}, ${placemark.locality}';
```

**Proveedor**: Geocoding package (usa varios proveedores)

### GPS y Ubicación

#### Permisos
**Android** (AndroidManifest.xml):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** (Info.plist):
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Necesitamos acceso a tu ubicación para mostrar artículos cercanos</string>
```

#### Estados de GPS
1. **Servicio Deshabilitado** - GPS apagado
2. **Sin Permisos** - Usuario no otorgó permisos
3. **Permisos Otorgados** - Listo para usar
4. **Ubicación Obtenida** - Coordenadas disponibles

#### Manejo de Errores
```dart
try {
  location = await getCurrentLocation();
} catch (e) {
  // Usa última ubicación conocida
  // O centra en Cochabamba por defecto
}
```

---

## 🔄 Flujos de Trabajo

### Workflow de Artículos

#### Estados del Artículo
1. **publicados** - Recién creado, visible a empresas
2. **vencido** - Expirado por tiempo (30+ días)
3. **completado** - Entregado y confirmado

#### Estados de Request (Solicitud)
1. **pendiente** - Empresa solicitó, esperando distribuidor
2. **aprobado** - Distribuidor aprobó, esperando asignación
3. **rechazado** - Distribuidor rechazó

#### Estados de Task (Tarea)
1. **sin_asignar** - Request aprobada, sin empleado
2. **asignado** - Empleado asignado por empresa
3. **en_proceso** - Empleado trabajando en recolección
4. **esperando_confirmacion_distribuidor** - Empleado confirmó
5. **esperando_confirmacion_empleado** - Distribuidor confirmó
6. **completado** - Ambos confirmaron + puntos + reseñas

### Flujo Completo Detallado

```
┌─────────────────────────────────────────────────────────────────┐
│ FASE 1: PUBLICACIÓN                                              │
└─────────────────────────────────────────────────────────────────┘
1. Distribuidor publica artículo
   - Valida límite (máx 3 activos)
   - Sube fotos
   - Configura disponibilidad
   → article.workflowStatus = 'publicados'

┌─────────────────────────────────────────────────────────────────┐
│ FASE 2: SOLICITUD                                                │
└─────────────────────────────────────────────────────────────────┘
2. Empresa ve artículo en mapa
3. Empresa solicita artículo
   - Selecciona día y hora
   → request.status = 'pendiente'
   → Notificación a distribuidor

┌─────────────────────────────────────────────────────────────────┐
│ FASE 3: APROBACIÓN                                               │
└─────────────────────────────────────────────────────────────────┘
4. Distribuidor revisa solicitud
   OPCIÓN A: Aprueba
     → request.status = 'aprobado'
     → Crea task automáticamente:
        - task.workflowStatus = 'sin_asignar'
        - task.companyID = empresa solicitante
        - task.requestID = solicitud
        - task.articleID = artículo
     → Notificación a empresa
   
   OPCIÓN B: Rechaza
     → request.status = 'rechazado'
     → Notificación a empresa
     → FIN (artículo vuelve a disponible)

┌─────────────────────────────────────────────────────────────────┐
│ FASE 4: ASIGNACIÓN                                               │
└─────────────────────────────────────────────────────────────────┘
5. Admin-empresa asigna empleado
   - Selecciona empleado de lista
   → task.employeeID = empleado
   → task.workflowStatus = 'asignado' → 'en_proceso'
   → Notificación a empleado

┌─────────────────────────────────────────────────────────────────┐
│ FASE 5: RECOLECCIÓN                                              │
└─────────────────────────────────────────────────────────────────┘
6. Empleado ve tarea en mapa
7. Empleado va a ubicación
8. Empleado confirma recolección
   → task.workflowStatus = 'esperando_confirmacion_distribuidor'
   → Notificación a distribuidor

┌─────────────────────────────────────────────────────────────────┐
│ FASE 6: CONFIRMACIÓN DISTRIBUIDOR                                │
└─────────────────────────────────────────────────────────────────┘
9. Distribuidor confirma entrega
   → task.workflowStatus = 'esperando_confirmacion_empleado'
   → O si empleado ya confirmó:
   → task.workflowStatus = 'completado'

┌─────────────────────────────────────────────────────────────────┐
│ FASE 7: FINALIZACIÓN                                             │
└─────────────────────────────────────────────────────────────────┘
10. Ambos confirmaron
    → task.workflowStatus = 'completado'
    → article.workflowStatus = 'completado'
    
11. Sistema de Puntos
    → +50 puntos al distribuidor (userPointsLog)
    → Se agregan al ciclo activo (current_ranking2)
    
12. Sistema de Reseñas
    → Modal para distribuidor → califica empleado
    → Modal para empleado → califica distribuidor
    → reviews.state = 1 (activo)
    
13. Artículo pasa a historial
    → No visible en mapas
    → Visible en perfiles (historial)
```

### Sistema de Puntos

#### Asignación de Puntos
```dart
+50 EXP por artículo completado
```

**Tabla**: userPointsLog
```sql
INSERT INTO userPointsLog (userID, taskID, points, createdAt)
VALUES (distributorId, taskId, 50, NOW())
```

#### Ranking Mensual
**Vista**: current_ranking2
- Calcula puntos totales por ciclo
- Ordena por puntos descendente
- Asigna posiciones
- Vincula a ciclo activo

**Ciclos**:
- Duración: ~30 días
- Estado: activo (state=1)
- Contador de días restantes
- Top 50 visible

### Sistema de Reseñas

#### Tipos de Reseñas
1. **Distribuidor → Empleado**
   - Califica recolección
   - Al completar tarea
   
2. **Empleado → Distribuidor**
   - Califica experiencia
   - Al completar tarea

3. **Empresa → Distribuidor**
   - Califica servicio
   - Opcional

#### Calificación
- **Estrellas**: 1-5
- **Comentario**: Opcional (texto)
- **Estado**: 1=activo, 0=inactivo
- **Vinculación**: taskID (nullable)

#### Promedio de Calificación
```dart
SELECT AVG(starID) as rating, COUNT(*) as totalReviews
FROM reviews
WHERE receiverID = userId AND state = 1
```

**Mostrado en**:
- Perfil de usuario
- Tarjeta de empleado
- Ranking (opcional)
- Detalle de artículo

---

## 📱 Dependencias Principales

### Análisis del pubspec.yaml

#### Backend y Auth
```yaml
supabase_flutter: ^2.10.0        # Backend as a Service
```

#### UI y Navegación
```yaml
cupertino_icons: ^1.0.8          # Iconos iOS
curved_navigation_bar: ^1.0.6    # Barra de navegación curva
```

#### Mapas
```yaml
flutter_map: ^8.2.1              # Widget de mapas
latlong2: ^0.9.1                 # Coordenadas
location: ^7.0.0                 # GPS
geocoding: ^4.0.0                # Dirección ↔ Coords
```

#### Multimedia
```yaml
image_picker: ^1.2.0             # Selector de imágenes
image_cropper: ^7.0.5            # Recorte de imágenes
image: ^4.2.0                    # Procesamiento
cached_network_image: ^3.4.0     # Cache de imágenes
flutter_cache_manager: ^3.4.1    # Gestión de cache
```

#### Permisos y Sistema
```yaml
permission_handler: ^12.0.1      # Permisos
path_provider: ^2.1.4            # Rutas del sistema
shared_preferences: ^2.5.3       # Storage local
```

#### Utilidades
```yaml
internet_connection_checker: ^1.0.0+1  # Estado de red
intl: ^0.19.0                           # Internacionalización
share_plus: ^9.0.0                      # Compartir
flutter_datetime_picker_plus: ^2.2.0    # Selector fecha/hora
```

#### Email
```yaml
mailer: ^6.6.0                   # Envío de correos
flutter_dotenv: ^6.0.0           # Variables de entorno
```

---

## 🎨 Diseño y Tema

### Paleta de Colores

#### Color Principal
```dart
const Color(0xFF2D8A8A)  // Teal oscuro
```

#### Variaciones
```dart
Colors.teal.shade50      // Muy claro (backgrounds)
Colors.teal.shade100     // Claro
Colors.teal.shade700     // Oscuro
Colors.teal.shade900     // Muy oscuro
```

#### Colores Secundarios
```dart
Colors.amber             // Puntos, estrellas
Colors.green             // Éxito, aprobado
Colors.red               // Error, rechazado
Colors.orange            // Advertencia, pendiente
Colors.blue              // Información
Colors.grey              // Neutro
```

### Tipografía

```dart
// Headers
fontSize: 24, fontWeight: FontWeight.bold

// Subtítulos
fontSize: 16, fontWeight: FontWeight.w600

// Cuerpo
fontSize: 14, fontWeight: FontWeight.normal

// Pequeño
fontSize: 12
```

### Espaciado (app_spacing.dart)
```dart
const double paddingSmall = 8.0;
const double paddingMedium = 16.0;
const double paddingLarge = 24.0;
const double paddingXLarge = 32.0;
```

### Bordes
```dart
borderRadius: BorderRadius.circular(12)  // Estándar
borderRadius: BorderRadius.circular(20)  // Redondeado
borderRadius: BorderRadius.circular(30)  // Muy redondeado
```

---

## 🔧 Configuración del Proyecto

### Requisitos Previos
- Flutter SDK 3.7.2+
- Dart 3.7.2+
- Android Studio / VS Code
- Cuenta de Supabase
- Git

### Variables de Entorno (.env)
```env
SUPABASE_URL=https://kasilxktkxwqheudkdpr.supabase.co
SUPABASE_ANON_KEY=eyJhbGc...
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=tu-email@gmail.com
SMTP_PASS=tu-password-app
```

### Instalación

```bash
# Clonar repositorio
git clone https://github.com/johanmerida8/AppReciclajeJJ.git
cd reciclaje_app

# Instalar dependencias
flutter pub get

# Crear .env
cp .env.example .env
# Editar .env con tus credenciales

# Ejecutar
flutter run
```

### Configuración de Supabase

1. **Crear proyecto** en supabase.com
2. **Ejecutar SQL** de database_setup/
3. **Configurar Storage** para multimedia
4. **Habilitar Email Auth**
5. **Configurar RLS** (Row Level Security)
6. **Copiar credenciales** a .env

### Build para Producción

#### Android
```bash
flutter build apk --release
# o
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### Web
```bash
flutter build web --release
```

---

## 📊 Estadísticas y Métricas

### Archivos del Proyecto
- **Total**: ~117 archivos .dart
- **Pantallas**: ~30
- **Componentes**: ~25
- **Servicios**: ~10
- **Modelos**: ~15
- **Database**: ~15

### Líneas de Código (aproximado)
- **Frontend**: ~15,000 líneas
- **SQL**: ~1,500 líneas
- **Total**: ~16,500 líneas

### Complejidad
- **Roles**: 4 diferentes
- **Tablas DB**: 14 principales
- **Vistas**: 2
- **Estados Workflow**: 10+
- **Pantallas por Rol**: 5-8

---

## 🐛 Solución de Problemas Comunes

### 1. Error de Mapas no Cargando
**Síntoma**: Mapa en blanco o tiles no cargan

**Solución**:
```dart
// Verificar conexión a internet
// Verificar URL de tiles
// Limpiar cache: flutter clean
```

### 2. GPS no Funciona
**Síntoma**: No obtiene ubicación

**Solución**:
```dart
// Verificar permisos en AndroidManifest.xml/Info.plist
// Verificar GPS activado en dispositivo
// Verificar que location package esté instalado
await _checkLocationServices();
```

### 3. Imágenes no Suben
**Síntoma**: Error al subir fotos

**Solución**:
```dart
// Verificar tamaño < 5MB
// Verificar formato (JPG, PNG)
// Verificar permisos de storage
// Verificar bucket de Supabase configurado
```

### 4. Notificaciones no Aparecen
**Síntoma**: Badge no actualiza

**Solución**:
```dart
// Verificar SharedPreferences
// Limpiar cache: prefs.clear()
// Verificar filtros de estado
await _loadPendingRequestCount();
```

### 5. Clustering no Funciona
**Síntoma**: Todos los marcadores sueltos

**Solución**:
```dart
// Verificar nivel de zoom
// Verificar _currentZoom se actualiza
// Verificar clusterItems() se llama
```

---

## 🚀 Próximas Mejoras Sugeridas

### Funcionalidades
- [ ] Chat en tiempo real
- [ ] Notificaciones push
- [ ] Filtros avanzados de búsqueda
- [ ] Modo oscuro
- [ ] Multiidioma (i18n)
- [ ] Exportar reportes PDF
- [ ] Integración con redes sociales
- [ ] Historial de ubicaciones
- [ ] Favoritos/guardados

### Técnicas
- [ ] Tests unitarios
- [ ] Tests de integración
- [ ] CI/CD pipeline
- [ ] Migración a Riverpod
- [ ] Optimización de imágenes
- [ ] Lazy loading mejorado
- [ ] Offline mode robusto
- [ ] Analytics

### UX/UI
- [ ] Onboarding tutorial
- [ ] Animaciones mejoradas
- [ ] Skeleton loaders
- [ ] Pull to refresh
- [ ] Gestos personalizados
- [ ] Feedback háptico
- [ ] Accesibilidad mejorada

---

## 📞 Contacto y Soporte

**Desarrollador**: Johan Merida  
**Email**: emsacercado@gmail.com  
**GitHub**: @johanmerida8  
**Repositorio**: AppReciclajeJJ  

**Universidad**: [Tu Universidad]  
**Materia**: Práctica Profesional 2-2025  

---

## 📄 Licencia

Este proyecto es privado y con fines educativos.

---

**Última Actualización**: 29 de Noviembre, 2025  
**Versión de la Documentación**: 1.0.0  
**Versión de la App**: 1.0.0+1
