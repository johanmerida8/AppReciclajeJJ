# Two-Way Confirmation Workflow - Testing Guide

## ✅ Fixed Issues
1. **Star Rating Overflow** - Fixed both employee and distributor rating dialogs by:
   - Reduced iconSize from 40 to 36
   - Added `mainAxisSize: MainAxisSize.min` to Row
   - Added padding: `EdgeInsets.all(4)` and proper constraints to IconButtons
   - Wrapped Row in Center widget

## 📋 Confirmation Workflow Overview

### Workflow States
1. `asignado` - Task assigned to employee
2. `en_proceso` - Task in progress (employee started)
3. `esperando_confirmacion_empleado` - Waiting for employee confirmation (distributor confirmed first)
4. `esperando_confirmacion_distribuidor` - Waiting for distributor confirmation (employee confirmed first)
5. `completado` - Both parties confirmed, task complete

### Two-Way Confirmation Logic

**Scenario 1: Employee confirms first (most common flow)**
```
1. Employee taps "Confirmar llegada" → Shows rating dialog
2. Employee rates and confirms → Status changes to 'esperando_confirmacion_distribuidor'
3. Distributor's real-time listener detects the change
4. Distributor sees automatic notification dialog: "Confirmar entrega"
5. Distributor confirms and rates → Status changes to 'completado'
```

**Scenario 2: Distributor confirms first**
```
1. Distributor taps "Confirmar entrega" → Shows rating dialog
2. Distributor rates and confirms → Status changes to 'esperando_confirmacion_empleado'
3. Employee's real-time listener detects the change
4. Employee sees automatic notification dialog: "Confirmar recepción"
5. Employee confirms and rates → Status changes to 'completado'
```

## 🔍 Testing Steps

### Test 1: Employee Confirms First
1. **Setup:**
   - Login as Employee (admin-empleado)
   - Navigate to article detail with status 'en_proceso'
   
2. **Action:**
   - Tap "Confirmar llegada" button
   - Rate the delivery (select stars)
   - Add optional comment
   - Tap "Enviar"

3. **Expected Results:**
   - ✅ Loading indicator shows
   - ✅ Review is saved to database
   - ✅ Task status updates to 'esperando_confirmacion_distribuidor'
   - ✅ Success message: "Confirmación enviada. Esperando confirmación del distribuidor."
   - ✅ Navigate back to employee home

4. **Distributor Side (Real-time):**
   - ✅ Distributor's detail screen automatically shows notification dialog
   - ✅ Dialog title: "Confirmar entrega"
   - ✅ Message: "El empleado confirmó la entrega. ¿Entregaste el objeto?"
   - ✅ Green background with check icon

5. **Distributor Action:**
   - ✅ Tap "Sí, confirmar" in notification dialog
   - ✅ Rating dialog appears
   - ✅ Rate and confirm

6. **Final Result:**
   - ✅ Task status becomes 'completado'
   - ✅ Both reviews saved
   - ✅ Success message: "¡Entrega completada exitosamente!"

### Test 2: Distributor Confirms First
1. **Setup:**
   - Login as Distributor (admin-empresa or article owner)
   - Navigate to article detail with status 'en_proceso'
   
2. **Action:**
   - Tap "Confirmar entrega" button
   - Rate the experience (select stars)
   - Add optional comment
   - Tap "Enviar"

3. **Expected Results:**
   - ✅ Loading indicator shows
   - ✅ Review is saved to database
   - ✅ Task status updates to 'esperando_confirmacion_empleado'
   - ✅ Success message: "Confirmación enviada. Esperando confirmación del empleado."
   - ✅ Navigate back to distributor home

4. **Employee Side (Real-time):**
   - ✅ Employee's detail screen automatically shows notification dialog
   - ✅ Dialog title: "Confirmar recepción"
   - ✅ Message: "El distribuidor confirmó la entrega. ¿Recibiste el objeto?"
   - ✅ Green background with check icon

5. **Employee Action:**
   - ✅ Tap "Sí, confirmar" in notification dialog
   - ✅ Rating dialog appears
   - ✅ Rate and confirm

6. **Final Result:**
   - ✅ Task status becomes 'completado'
   - ✅ Both reviews saved
   - ✅ Success message: "¡Entrega completada exitosamente!"

## 🔧 Real-time Listeners

### Employee Listener
```dart
_setupEmployeeTaskStatusListener() {
  // Listens on 'tasks' table for updates
  // Filter: eq('assignedTo', _employeeId)
  // Triggers: When status changes to 'esperando_confirmacion_empleado'
  // Action: Shows _showDistributorConfirmedNotification()
}
```

### Distributor Listener
```dart
_setupTaskStatusListener() {
  // Listens on 'tasks' table for updates
  // Filter: eq('articleID', widget.item.id)
  // Triggers: When status changes to 'esperando_confirmacion_distribuidor'
  // Action: Shows _showEmployeeConfirmedNotification()
}
```

## 📊 Database Changes

### Review Table Inserts
**Employee Review (rates distributor/company):**
```json
{
  "starID": 5,
  "articleID": 123,
  "senderID": employeeUserID,
  "receiverID": distributorUserID,
  "comment": "Excelente servicio",
  "state": 1,
  "created_at": "2025-01-20T10:30:00Z"
}
```

**Distributor Review (rates employee/company):**
```json
{
  "starID": 4,
  "articleID": 123,
  "senderID": distributorUserID,
  "receiverID": employeeUserID,
  "comment": "Muy profesional",
  "state": 1,
  "created_at": "2025-01-20T10:35:00Z"
}
```

### Task Status Updates
```sql
-- Employee confirms first
UPDATE tasks 
SET workflowStatus = 'esperando_confirmacion_distribuidor', 
    lastUpdate = NOW()
WHERE idTask = ?;

-- Distributor confirms second (both confirmed)
UPDATE tasks 
SET workflowStatus = 'completado', 
    lastUpdate = NOW()
WHERE idTask = ?;
```

## ⚠️ Important Notes

1. **Real-time Requires Open Screen:**
   - The real-time listener only works if the detail screen is open
   - If closed, the notification won't appear automatically
   - User must navigate to the article detail to see the status change

2. **Status Indicators:**
   - Employee sees amber badge: "En Proceso - Esta tarea está asignada a ti"
   - When waiting for confirmation, shows green message box above button
   - Button text changes: "Confirmar llegada" → "Confirmar recepción"

3. **Rating is Required:**
   - Both dialogs disable submit button until at least 1 star is selected
   - Comment is optional (max 200 characters)

4. **Navigation After Confirmation:**
   - Employee navigates to: `EmployeeNavigationScreens()`
   - Distributor navigates to: `NavigationScreens()`

## 🐛 Debugging Commands

```dart
// Check current task status
print('Employee task status: $_employeeTaskStatus');
print('Distributor task status: $_distributorTaskStatus');

// Verify listener is active
print('Task subscription active: ${_taskSubscription != null}');

// Check real-time event
print('Received update event: ${event.eventType}');
print('New status: ${newData['workflowStatus']}');
```

## ✅ Success Criteria

- [ ] Star rating dialogs don't overflow
- [ ] Employee can confirm arrival and rate
- [ ] Distributor receives real-time notification
- [ ] Distributor can confirm delivery and rate
- [ ] Task status becomes 'completado' only after both confirmations
- [ ] Both reviews are saved correctly
- [ ] Workflow works in reverse order (distributor first)
- [ ] Success messages show appropriate text
- [ ] Navigation works correctly after confirmation

## 📝 Notes for Testing

1. **Test both orders:**
   - Employee confirms first
   - Distributor confirms first

2. **Test UI:**
   - Verify no overflow errors in console
   - Check star rating is clickable
   - Verify comment field works

3. **Test real-time:**
   - Keep both screens open simultaneously
   - Confirm on one device
   - Check notification appears on other device

4. **Test database:**
   - Verify both reviews are created
   - Check task status is 'completado'
   - Confirm lastUpdate timestamp is current
