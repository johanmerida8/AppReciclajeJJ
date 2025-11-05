-- ============================================================================
-- TABLA: tasks
-- Descripción: Gestiona las asignaciones de artículos de reciclaje a empleados
-- ============================================================================

CREATE TABLE IF NOT EXISTS tasks (
  idTask SERIAL PRIMARY KEY,
  
  -- Referencias a otras tablas
  employeeID INTEGER NOT NULL REFERENCES employees(idEmployee) ON DELETE CASCADE,
  articleID INTEGER NOT NULL REFERENCES article(idArticle) ON DELETE CASCADE,
  companyID INTEGER NOT NULL REFERENCES company(idCompany) ON DELETE CASCADE,
  assignedBy INTEGER NOT NULL REFERENCES users(idUsers), -- admin-empresa que asignó
  
  -- Estado y prioridad
  status VARCHAR(20) NOT NULL DEFAULT 'sin_asignar' CHECK (status IN (
    'sin_asignar',   -- Creada pero no asignada aún
    'asignado',      -- Asignada al empleado
    'en_proceso',    -- Empleado está trabajando en ella
    'completado',    -- Tarea completada exitosamente
    'cancelado'      -- Tarea cancelada
  )),
  priority VARCHAR(10) DEFAULT 'media' CHECK (priority IN ('baja', 'media', 'alta', 'urgente')),
  
  -- Fechas y tiempos
  assignedDate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  startDate TIMESTAMP,           -- Cuando el empleado inicia la tarea
  completedDate TIMESTAMP,       -- Cuando se completa
  dueDate DATE,                  -- Fecha límite opcional
  
  -- Notas y observaciones
  notes TEXT,                    -- Notas del admin al asignar
  employeeNotes TEXT,            -- Notas del empleado durante/después de la tarea
  
  -- Duración estimada vs real (en minutos)
  estimatedDuration INTEGER,     
  actualDuration INTEGER,
  
  -- Información de ubicación (opcional, si el empleado reporta su ubicación)
  collectionLatitude DOUBLE PRECISION,
  collectionLongitude DOUBLE PRECISION,
  
  -- Metadata
  lastUpdate TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ÍNDICES para mejorar el rendimiento de consultas
-- ============================================================================

-- Buscar tareas por empleado
CREATE INDEX idx_tasks_employee ON tasks(employeeID);

-- Buscar tareas por artículo
CREATE INDEX idx_tasks_article ON tasks(articleID);

-- Buscar tareas por empresa
CREATE INDEX idx_tasks_company ON tasks(companyID);

-- Filtrar por estado
CREATE INDEX idx_tasks_status ON tasks(status);

-- Ordenar por fecha de asignación
CREATE INDEX idx_tasks_assigned_date ON tasks(assignedDate DESC);

-- Buscar por fecha límite
CREATE INDEX idx_tasks_due_date ON tasks(dueDate);

-- Índice compuesto para consultas comunes (empresa + estado)
CREATE INDEX idx_tasks_company_status ON tasks(companyID, status);

-- ============================================================================
-- TRIGGER para actualizar lastUpdate automáticamente
-- ============================================================================

CREATE OR REPLACE FUNCTION update_task_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.lastUpdate = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER task_update_timestamp
BEFORE UPDATE ON tasks
FOR EACH ROW
EXECUTE FUNCTION update_task_timestamp();

-- ============================================================================
-- TRIGGER para actualizar automáticamente las fechas según el estado
-- ============================================================================

CREATE OR REPLACE FUNCTION update_task_status_dates()
RETURNS TRIGGER AS $$
BEGIN
  -- Si cambia a 'en_proceso', establecer startDate
  IF NEW.status = 'en_proceso' AND OLD.status != 'en_proceso' THEN
    NEW.startDate = CURRENT_TIMESTAMP;
  END IF;
  
  -- Si cambia a 'completado', establecer completedDate
  IF NEW.status = 'completado' AND OLD.status != 'completado' THEN
    NEW.completedDate = CURRENT_TIMESTAMP;
    
    -- Calcular duración real si existe startDate
    IF NEW.startDate IS NOT NULL THEN
      NEW.actualDuration = EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - NEW.startDate)) / 60;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER task_status_dates
BEFORE UPDATE ON tasks
FOR EACH ROW
WHEN (OLD.status IS DISTINCT FROM NEW.status)
EXECUTE FUNCTION update_task_status_dates();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Habilitar RLS
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Política: admin-empresa puede ver todas las tareas de su empresa
CREATE POLICY tasks_company_admin_policy ON tasks
  FOR ALL
  USING (
    companyID IN (
      SELECT c.idCompany 
      FROM company c
      JOIN users u ON c.idUserAdmin = u.idUsers
      WHERE u.email = auth.email()
    )
  );

-- Política: empleados pueden ver solo sus propias tareas
CREATE POLICY tasks_employee_policy ON tasks
  FOR SELECT
  USING (
    employeeID IN (
      SELECT e.idEmployee
      FROM employees e
      JOIN users u ON e.userID = u.idUsers
      WHERE u.email = auth.email()
    )
  );

-- Política: empleados pueden actualizar solo sus propias tareas
CREATE POLICY tasks_employee_update_policy ON tasks
  FOR UPDATE
  USING (
    employeeID IN (
      SELECT e.idEmployee
      FROM employees e
      JOIN users u ON e.userID = u.idUsers
      WHERE u.email = auth.email()
    )
  )
  WITH CHECK (
    -- Empleados solo pueden cambiar: status, employeeNotes, collectionLatitude, collectionLongitude
    employeeID IN (
      SELECT e.idEmployee
      FROM employees e
      JOIN users u ON e.userID = u.idUsers
      WHERE u.email = auth.email()
    )
  );

-- ============================================================================
-- VISTAS ÚTILES
-- ============================================================================

-- Vista con información completa de la tarea
CREATE OR REPLACE VIEW tasks_detailed AS
SELECT 
  t.idTask,
  t.status,
  t.priority,
  t.assignedDate,
  t.startDate,
  t.completedDate,
  t.dueDate,
  t.notes,
  t.employeeNotes,
  t.estimatedDuration,
  t.actualDuration,
  -- Información del empleado
  e.idEmployee,
  ue.name AS employeeName,
  ue.email AS employeeEmail,
  ue.phone AS employeePhone,
  -- Información del artículo
  a.idArticle,
  a.name AS articleName,
  a.categoryID,
  a.condition AS articleCondition,
  a.description AS articleDescription,
  -- Información de ubicación del artículo
  d.address AS articleAddress,
  d.lat AS articleLatitude,
  d.lng AS articleLongitude,
  -- Información del dueño del artículo
  ua.name AS articleOwnerName,
  ua.email AS articleOwnerEmail,
  ua.phone AS articleOwnerPhone,
  -- Información de la empresa
  c.idCompany,
  c.name AS companyName,
  c.email AS companyEmail,
  -- Información del asignador
  uadmin.name AS assignedByName,
  uadmin.email AS assignedByEmail
FROM tasks t
JOIN employees e ON t.employeeID = e.idEmployee
JOIN users ue ON e.userID = ue.idUsers
JOIN article a ON t.articleID = a.idArticle
JOIN deliver d ON a.deliverID = d.idDeliver
JOIN users ua ON a.userID = ua.idUsers
JOIN company c ON t.companyID = c.idCompany
JOIN users uadmin ON t.assignedBy = uadmin.idUsers;

-- ============================================================================
-- FUNCIONES ÚTILES
-- ============================================================================

-- Función: Obtener estadísticas de tareas por empleado
CREATE OR REPLACE FUNCTION get_employee_task_stats(emp_id INTEGER)
RETURNS TABLE(
  total_tasks BIGINT,
  pending_tasks BIGINT,
  in_progress_tasks BIGINT,
  completed_tasks BIGINT,
  avg_completion_time DOUBLE PRECISION
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) AS total_tasks,
    COUNT(*) FILTER (WHERE status = 'asignado') AS pending_tasks,
    COUNT(*) FILTER (WHERE status = 'en_proceso') AS in_progress_tasks,
    COUNT(*) FILTER (WHERE status = 'completado') AS completed_tasks,
    AVG(actualDuration) FILTER (WHERE status = 'completado') AS avg_completion_time
  FROM tasks
  WHERE employeeID = emp_id;
END;
$$ LANGUAGE plpgsql;

-- Función: Obtener tareas vencidas
CREATE OR REPLACE FUNCTION get_overdue_tasks(comp_id INTEGER)
RETURNS TABLE(
  idTask INTEGER,
  articleName VARCHAR,
  employeeName VARCHAR,
  dueDate DATE,
  daysOverdue INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    t.idTask,
    a.name AS articleName,
    u.name AS employeeName,
    t.dueDate,
    (CURRENT_DATE - t.dueDate)::INTEGER AS daysOverdue
  FROM tasks t
  JOIN article a ON t.articleID = a.idArticle
  JOIN employees e ON t.employeeID = e.idEmployee
  JOIN users u ON e.userID = u.idUsers
  WHERE t.companyID = comp_id
    AND t.dueDate < CURRENT_DATE
    AND t.status NOT IN ('completado', 'cancelado')
  ORDER BY daysOverdue DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- DATOS DE EJEMPLO (opcional, comentar en producción)
-- ============================================================================

-- Descomentar estas líneas para insertar datos de prueba
/*
INSERT INTO tasks (employeeID, articleID, companyID, assignedBy, status, priority, notes, estimatedDuration, dueDate)
VALUES 
  (1, 1, 1, 2, 'asignado', 'alta', 'Recolectar antes del mediodía', 30, CURRENT_DATE + 2),
  (1, 2, 1, 2, 'en_proceso', 'media', 'Material frágil, manejar con cuidado', 45, CURRENT_DATE + 3),
  (2, 3, 1, 2, 'completado', 'baja', 'Recolección rutinaria', 25, CURRENT_DATE - 1);
*/
