import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// ✅ Schedule Pickup Dialog with time window selection
class SchedulePickupDialog extends StatefulWidget {
  final String? availableDays;
  final String? availableTimeStart;
  final String? availableTimeEnd;
  final String articleName;
  final List<Map<String, dynamic>>? daysAvailableData; // New: actual date-based availability

  const SchedulePickupDialog({
    super.key,
    this.availableDays,
    this.availableTimeStart,
    this.availableTimeEnd,
    required this.articleName,
    this.daysAvailableData,
  });

  @override
  State<SchedulePickupDialog> createState() => _SchedulePickupDialogState();
}

class _SchedulePickupDialogState extends State<SchedulePickupDialog> {
  String? _selectedDay;
  int? _selectedIndex;
  TimeOfDay? _selectedStartTime;
  late TimeOfDay _availableStartTime;
  late TimeOfDay _availableEndTime;
  late List<Map<String, dynamic>> _availabilityList;

  @override
  void initState() {
    super.initState();
    _parseAvailability();
  }

  void _parseAvailability() {
    if (widget.daysAvailableData != null && widget.daysAvailableData!.isNotEmpty) {
      // Use new date-based availability
      _availabilityList = widget.daysAvailableData!;
      _selectedIndex = 0;
      
      // Parse first day's times
      final firstDay = _availabilityList[0];
      _parseTimesFromData(firstDay);
      _selectedDay = firstDay['dateAvailable'] as String;
    } else {
      // Fallback to old format
      _availabilityList = [];
      _parseAvailableDaysOldFormat();
      _parseAvailableTimesOldFormat();
    }
  }

  void _parseAvailableDaysOldFormat() {
    final List<Map<String, dynamic>> tempList = [];
    
    if (widget.availableDays == null || widget.availableDays!.isEmpty) {
      final dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      for (var day in dayNames) {
        tempList.add({'dayName': day, 'dateAvailable': day});
      }
    } else {
      final days = widget.availableDays!.split(',').map((d) => d.trim()).toList();
      for (var day in days) {
        tempList.add({'dayName': day, 'dateAvailable': day});
      }
    }
    
    _availabilityList = tempList;
    if (_availabilityList.isNotEmpty) {
      _selectedIndex = 0;
      _selectedDay = _availabilityList[0]['dateAvailable'] as String;
    }
  }

  void _parseTimesFromData(Map<String, dynamic> dayData) {
    try {
      final startTimeStr = dayData['startTime'] as String? ?? '08:00:00';
      final endTimeStr = dayData['endTime'] as String? ?? '18:00:00';
      
      final startParts = startTimeStr.split(':');
      _availableStartTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      final endParts = endTimeStr.split(':');
      _availableEndTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      _selectedStartTime = _availableStartTime;
    } catch (e) {
      print('❌ Error parsing times: $e');
      _availableStartTime = const TimeOfDay(hour: 8, minute: 0);
      _availableEndTime = const TimeOfDay(hour: 17, minute: 0);
      _selectedStartTime = _availableStartTime;
    }
  }

  void _parseAvailableTimesOldFormat() {
    try {
      final startTimeStr = widget.availableTimeStart ?? '08:00:00';
      final endTimeStr = widget.availableTimeEnd ?? '18:00:00';
      
      final startParts = startTimeStr.split(':');
      _availableStartTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      final endParts = endTimeStr.split(':');
      _availableEndTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      _selectedStartTime = _availableStartTime;
    } catch (e) {
      print('❌ Error parsing times: $e');
      _availableStartTime = const TimeOfDay(hour: 8, minute: 0);
      _availableEndTime = const TimeOfDay(hour: 17, minute: 0);
      _selectedStartTime = _availableStartTime;
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ?? _availableStartTime,
      helpText: 'Selecciona hora de inicio',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2D8A8A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final pickedMinutes = picked.hour * 60 + picked.minute;
      final availableStartMinutes = _availableStartTime.hour * 60 + _availableStartTime.minute;
      final availableEndMinutes = _availableEndTime.hour * 60 + _availableEndTime.minute;

      if (pickedMinutes < availableStartMinutes || pickedMinutes >= availableEndMinutes) {
        _showError('La hora debe estar entre ${_availableStartTime.format(context)} y ${_availableEndTime.format(context)}');
      } else {
        setState(() {
          _selectedStartTime = picked;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.schedule, color: Color(0xFF2D8A8A)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Horas y días Disponibles',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2D8A8A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Importante: Selecciona un día y hora para coordinar la recolección del objeto. El dueño recibirá tu Solicitud.',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _pickStartTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2D8A8A), width: 2),
                    ),
                    child: Text(
                      _selectedStartTime != null ? _selectedStartTime!.hour.toString().padLeft(2, '0') : '00',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                ),
                InkWell(
                  onTap: _pickStartTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2D8A8A), width: 2),
                    ),
                    child: Text(
                      _selectedStartTime != null ? _selectedStartTime!.minute.toString().padLeft(2, '0') : '00',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Disponible: ${_availableStartTime.format(context)} - ${_availableEndTime.format(context)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Días Disponibles',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                if (_availabilityList.isNotEmpty && _availabilityList[0].containsKey('dateAvailable'))
                  Text(
                    _getMonthName(_availabilityList[0]['dateAvailable'] as String),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_availabilityList.length, (index) {
                final dayData = _availabilityList[index];
                final isSelected = index == _selectedIndex;
                return ChoiceChip(
                  label: Text(_formatDayLabel(dayData)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedIndex = index;
                      _selectedDay = dayData['dateAvailable'] as String;
                      _parseTimesFromData(dayData);
                    });
                  },
                  selectedColor: const Color(0xFF2D8A8A),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('cancelar'),
        ),
        ElevatedButton(
          onPressed: _selectedDay != null && _selectedStartTime != null
              ? () {
                  Navigator.pop(context, {
                    'day': _selectedDay!,
                    'startTime': _formatTime(_selectedStartTime!),
                    'endTime': _formatTime(_availableEndTime),
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D8A8A),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: const Text('Solicitar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  String _getShortDay(String fullDay) {
    final dayMap = {
      'Lunes': 'Lun',
      'Martes': 'Mar',
      'Miércoles': 'Mié',
      'Miercoles': 'Mié',
      'Jueves': 'Jue',
      'Viernes': 'Vie',
      'Sábado': 'Sáb',
      'Sabado': 'Sáb',
      'Domingo': 'Dom',
    };
    return dayMap[fullDay] ?? fullDay.substring(0, 3);
  }

  String _formatDayLabel(Map<String, dynamic> dayData) {
    // If we have dateAvailable, format it as "Sáb 22"
    if (dayData.containsKey('dateAvailable')) {
      try {
        final dateStr = dayData['dateAvailable'] as String;
        final date = DateTime.parse(dateStr);
        
        // Use simple Spanish day names instead of DateFormat
        final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
        final dayName = dayNames[date.weekday - 1];
        final dayNumber = date.day;
        
        return '$dayName $dayNumber';
      } catch (e) {
        print('❌ Error parsing date: $e');
      }
    }
    
    // Fallback to dayName if available
    if (dayData.containsKey('dayName')) {
      return _getShortDay(dayData['dayName'] as String);
    }
    
    return 'Día';
  }

  String _getMonthName(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      
      // Simple Spanish month names
      const monthNames = [
        'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ];
      
      return monthNames[date.month - 1];
    } catch (e) {
      return '';
    }
  }
}
