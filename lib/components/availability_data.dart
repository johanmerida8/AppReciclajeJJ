import 'package:flutter/material.dart';

class AvailabilityData {
  final List<String> selectedDays;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;

  AvailabilityData({
    required this.selectedDays,
    this.startTime,
    this.endTime,
  });

  // convert to database format
  String getDaysForDatabase() {
    return selectedDays.join(',');
  }

  String? getStartTimeForDatabase() {
    if (startTime == null) return null;

    // for postgresql time type, use HH:mm:ss format
    final hour = startTime!.hour.toString().padLeft(2, '0');
    final minute = startTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String? getEndTimeForDatabase() {
    if (endTime == null) return null;
    final hour = endTime!.hour.toString().padLeft(2, '0');  
    final minute = endTime!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // create from database format
  static AvailabilityData? fromDatabase({
    String? days,
    String? startTime,
    String? endTime,
  }) {
    if (days == null || days.isEmpty) return null;

    return AvailabilityData(
      selectedDays: days.split(','),
      startTime: _parseTimeFromDatabase(startTime),
      endTime: _parseTimeFromDatabase(endTime),
    );
  }

  static TimeOfDay? _parseTimeFromDatabase(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;

    try {
      // parse "8:00" or "17:30" (24 hour format from database)
      final parts = timeStr.split(':');
      if (parts.isEmpty || parts.length < 2) return null;

      final hour = int.parse(parts[0]); 
      final minute = int.parse(parts[1]);

      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      print('Error parsing time from database: $e');
      return null;
    }
  } 

  bool get isComplete => selectedDays.isNotEmpty && startTime != null && endTime != null;

  String getDisplayText() {
    if (selectedDays.isEmpty) return 'No hay días seleccionados';
    
    final daysText = selectedDays.join(', ');
    
    if (startTime != null && endTime != null) {
      return '$daysText\n${_formatTime(startTime!)} - ${_formatTime(endTime!)}';
    }
    
    return daysText;
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  
}

class AvailabilityPicker extends StatelessWidget {
  final AvailabilityData? selectedAvailability;
  final Function(AvailabilityData)? onAvailabilitySelected;
  final String labelText;
  final IconData? prefixIcon;
  final bool isRequired;

  const AvailabilityPicker({
    super.key,
    required this.selectedAvailability,
    this.onAvailabilitySelected,
    this.labelText = 'Disponibilidad para entrega',
    this.prefixIcon = Icons.calendar_month,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    // checks if disabled
    final bool isDisabled = onAvailabilitySelected == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Row(
          children: [
            Text(
              labelText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D8A8A),
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Availability Picker Container
        GestureDetector(
          onTap: isDisabled ? null : () => _showAvailabilityPicker(context),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: selectedAvailability == null 
                    ? Colors.grey 
                    : const Color(0xFF2D8A8A),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: selectedAvailability == null 
                  ? Colors.grey.shade50
                  : isDisabled
                      ? Colors.grey.shade50
                      : const Color(0xFF2D8A8A).withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(
                  prefixIcon,
                  color: selectedAvailability == null 
                      ? Colors.grey 
                      : isDisabled
                          ? Colors.grey.shade600
                          : const Color(0xFF2D8A8A),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedAvailability == null 
                            ? 'Seleccionar disponibilidad'
                            : 'Disponibilidad configurada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: selectedAvailability == null 
                              ? Colors.grey.shade600
                              : isDisabled
                                  ? Colors.grey.shade600
                                  : const Color(0xFF2D8A8A),
                        ),
                      ),
                      if (selectedAvailability != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          selectedAvailability!.getDisplayText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isDisabled)
                Icon(
                  selectedAvailability == null 
                      ? Icons.add 
                      : Icons.edit,
                  color: selectedAvailability == null 
                      ? Colors.grey 
                      : const Color(0xFF2D8A8A),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAvailabilityPicker(BuildContext context) {
    // only show if not disabled
    if (onAvailabilitySelected == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AvailabilityPickerDialog(
          initialAvailability: selectedAvailability,
          onConfirm: (availability) {
            Navigator.pop(context);
            onAvailabilitySelected!(availability);
          },
        );
      },
    );
  }
}

class _AvailabilityPickerDialog extends StatefulWidget {
  final AvailabilityData? initialAvailability;
  final Function(AvailabilityData) onConfirm;

  const _AvailabilityPickerDialog({
    required this.initialAvailability,
    required this.onConfirm,
  });

  @override
  State<_AvailabilityPickerDialog> createState() => _AvailabilityPickerDialogState();
}

class _AvailabilityPickerDialogState extends State<_AvailabilityPickerDialog> {
  late List<String> _selectedDays;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<Map<String, dynamic>> _weekDays = [];

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.initialAvailability?.selectedDays ?? [];
    _startTime = widget.initialAvailability?.startTime;
    _endTime = widget.initialAvailability?.endTime;
    _buildWeekDays();
  }

  void _buildWeekDays() {
    final today = DateTime.now();
    final currentWeekday = today.weekday; // 1 = Monday, 7 = Sunday
    
    // Start from Monday of current week
    final monday = today.subtract(Duration(days: currentWeekday - 1));
    
    final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final shortNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final monthNames = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      _weekDays.add({
        'full': dayNames[i],
        'short': shortNames[i],
        'dayNumber': date.day,
        'month': monthNames[date.month - 1],
        'date': date,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month,
                    color: Color(0xFF2D8A8A),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Selecciona tu disponibilidad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D8A8A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Days Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Días Disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D8A8A),
                    ),
                  ),
                  if (_weekDays.isNotEmpty)
                    Text(
                      _weekDays.first['month'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Days Grid with dates
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _weekDays.map((day) {
                  final isSelected = _selectedDays.contains(day['full']);
                  final dayNumber = day['dayNumber'];
                  final shortName = day['short'];
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedDays.remove(day['full']);
                        } else {
                          _selectedDays.add(day['full'] as String);
                        }
                      });
                    },
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF2D8A8A) 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF2D8A8A) 
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            shortName.toString(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dayNumber.toString(),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (isSelected)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Hours Section
              const Text(
                'Horas Disponibles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  // Start Time
                  Expanded(
                    child: _TimePickerButton(
                      label: 'Desde',
                      time: _startTime,
                      onTap: () => _selectTime(context, true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // End Time
                  Expanded(
                    child: _TimePickerButton(
                      label: 'Hasta',
                      time: _endTime,
                      onTap: () => _selectTime(context, false),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Warning message for single day selection
              if (_selectedDays.length == 1)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recomendamos seleccionar al menos 2-3 días para dar más flexibilidad a las empresas de reciclaje al programar la recolección.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Confirm Button
              ElevatedButton(
                onPressed: _selectedDays.isNotEmpty && _startTime != null && _endTime != null
                    ? () {
                        widget.onConfirm(
                          AvailabilityData(
                            selectedDays: _selectedDays,
                            startTime: _startTime,
                            endTime: _endTime,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D8A8A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text(
                  'Confirmar Disponibilidad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStartTime ? _startTime : _endTime) ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D8A8A),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
}

class _TimePickerButton extends StatelessWidget {
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;

  const _TimePickerButton({
    required this.label,
    required this.time,
    required this.onTap,
  });

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: time == null ? Colors.grey.shade300 : const Color(0xFF2D8A8A),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color: time == null ? Colors.grey.shade50 : const Color(0xFF2D8A8A).withOpacity(0.1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  time == null ? '00:00' : _formatTime(time!),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: time == null ? Colors.grey.shade400 : const Color(0xFF2D8A8A),
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color: time == null ? Colors.grey.shade400 : const Color(0xFF2D8A8A),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}