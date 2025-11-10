import 'package:flutter/material.dart';

/// ✅ Schedule Pickup Dialog
class SchedulePickupDialog extends StatefulWidget {
  final String availableDays;
  final String availableTimeStart;
  final String availableTimeEnd;
  final String articleName;

  const SchedulePickupDialog({
    super.key,
    required this.availableDays,
    required this.availableTimeStart,
    required this.availableTimeEnd,
    required this.articleName,
  });

  @override
  State<SchedulePickupDialog> createState() => _SchedulePickupDialogState();
}

class _SchedulePickupDialogState extends State<SchedulePickupDialog> {
  String? _selectedDay;
  TimeOfDay? _selectedTime;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late List<String> _availableDaysList;

  @override
  void initState() {
    super.initState();
    _parseAvailableDays();
    _parseAvailableTimes();
  }

  void _parseAvailableDays() {
    // Parse available days from format like "Lunes,Miércoles,Viernes"
    final days = widget.availableDays.split(',').map((d) => d.trim()).toList();
    _availableDaysList = days;
    
    // Auto-select first available day
    if (_availableDaysList.isNotEmpty) {
      _selectedDay = _availableDaysList.first;
    }
  }

  void _parseAvailableTimes() {
    // Parse time from "HH:MM:SS" format
    try {
      final startParts = widget.availableTimeStart.split(':');
      _startTime = TimeOfDay(
        hour: int.parse(startParts[0]),
        minute: int.parse(startParts[1]),
      );

      final endParts = widget.availableTimeEnd.split(':');
      _endTime = TimeOfDay(
        hour: int.parse(endParts[0]),
        minute: int.parse(endParts[1]),
      );

      // Auto-select start time as default
      _selectedTime = _startTime;
    } catch (e) {
      print('❌ Error parsing times: $e');
      _startTime = const TimeOfDay(hour: 8, minute: 0);
      _endTime = const TimeOfDay(hour: 17, minute: 0);
      _selectedTime = _startTime;
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? _startTime,
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
      // Validate time is within available range
      final pickedMinutes = picked.hour * 60 + picked.minute;
      final startMinutes = _startTime.hour * 60 + _startTime.minute;
      final endMinutes = _endTime.hour * 60 + _endTime.minute;

      if (pickedMinutes >= startMinutes && pickedMinutes <= endMinutes) {
        setState(() {
          _selectedTime = picked;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'La hora debe estar entre ${_startTime.format(context)} y ${_endTime.format(context)}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
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
            // Important notice
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

            // Time Picker
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Hour
                InkWell(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedTime != null ? _selectedTime!.hour.toString().padLeft(2, '0') : '00',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                ),
                // Minute
                InkWell(
                  onTap: _pickTime,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _selectedTime != null ? _selectedTime!.minute.toString().padLeft(2, '0') : '00',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${_startTime.format(context)} - ${_endTime.format(context)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            const SizedBox(height: 24),

            // Days selector
            const Text(
              'Días Disponibles',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _availableDaysList.map((day) {
                final isSelected = day == _selectedDay;
                return ChoiceChip(
                  label: Text(_getShortDay(day)),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedDay = day;
                    });
                  },
                  selectedColor: const Color(0xFF2D8A8A),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[700],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
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
          onPressed: _selectedDay != null && _selectedTime != null
              ? () {
                  Navigator.pop(context, {
                    'day': _selectedDay!,
                    'time': _formatTime(_selectedTime!),
                  });
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D8A8A),
            disabledBackgroundColor: Colors.grey[300],
          ),
          child: const Text('Solicitar'),
        ),
      ],
    );
  }

  String _getShortDay(String fullDay) {
    final dayMap = {
      'Lunes': 'Lun',
      'Martes': 'Mar',
      'Miércoles': 'Mír',
      'Miercoles': 'Mír',
      'Jueves': 'Jue',
      'Viernes': 'Vie',
      'Sábado': 'Sáb',
      'Sabado': 'Sáb',
      'Domingo': 'Dom',
    };
    return dayMap[fullDay] ?? fullDay.substring(0, 3);
  }
}
