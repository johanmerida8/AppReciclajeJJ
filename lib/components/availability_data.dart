import 'package:flutter/material.dart';

// ✅ New model to store time range for each day
class DayTimeRange {
  final String dayName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  DayTimeRange({
    required this.dayName,
    required this.date,
    required this.startTime,
    required this.endTime,
  });
}

class AvailabilityData {
  final List<String> selectedDays;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final Map<String, DayTimeRange>?
  perDayTimes; // ✅ New: store different times per day

  AvailabilityData({
    required this.selectedDays,
    this.startTime,
    this.endTime,
    this.perDayTimes,
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

  bool get isComplete =>
      selectedDays.isNotEmpty &&
      (perDayTimes != null
          ? perDayTimes!.length == selectedDays.length
          : (startTime != null && endTime != null));

  /// ✅ Check if availability data has changed
  bool isEqualTo(AvailabilityData? other) {
    if (other == null) return false;

    // Check if days are the same
    if (selectedDays.length != other.selectedDays.length) return false;
    for (int i = 0; i < selectedDays.length; i++) {
      if (selectedDays[i] != other.selectedDays[i]) return false;
    }

    // Check per-day times if present
    if (perDayTimes != null || other.perDayTimes != null) {
      if (perDayTimes == null || other.perDayTimes == null) return false;
      if (perDayTimes!.length != other.perDayTimes!.length) return false;

      // Compare each day's times and dates
      for (var entry in perDayTimes!.entries) {
        final otherDayTime = other.perDayTimes![entry.key];
        if (otherDayTime == null) return false;

        final dayTime = entry.value;
        // Compare dates (year, month, day)
        if (dayTime.date.year != otherDayTime.date.year ||
            dayTime.date.month != otherDayTime.date.month ||
            dayTime.date.day != otherDayTime.date.day)
          return false;
        // Compare start and end times
        if (dayTime.startTime.hour != otherDayTime.startTime.hour ||
            dayTime.startTime.minute != otherDayTime.startTime.minute)
          return false;
        if (dayTime.endTime.hour != otherDayTime.endTime.hour ||
            dayTime.endTime.minute != otherDayTime.endTime.minute)
          return false;
      }

      return true;
    }

    // Check regular times if no per-day times
    if (startTime?.hour != other.startTime?.hour ||
        startTime?.minute != other.startTime?.minute)
      return false;
    if (endTime?.hour != other.endTime?.hour ||
        endTime?.minute != other.endTime?.minute)
      return false;

    return true;
  }

  String getDisplayText() {
    if (selectedDays.isEmpty) return 'No hay días seleccionados';

    // If we have per-day times, show detailed list
    if (perDayTimes != null && perDayTimes!.isNotEmpty) {
      // Sort by date
      final sortedEntries =
          perDayTimes!.entries.toList()
            ..sort((a, b) => a.value.date.compareTo(b.value.date));

      // Format each day with date and time
      return sortedEntries
          .map((entry) {
            final dayTime = entry.value;
            final formattedDate = _formatDate(dayTime.date);
            final startStr = _formatTime(dayTime.startTime);
            final endStr = _formatTime(dayTime.endTime);
            return '$formattedDate: $startStr - $endStr';
          })
          .join('\n');
    }

    final daysText = selectedDays.join(', ');

    if (startTime != null && endTime != null) {
      return '$daysText\n${_formatTime(startTime!)} - ${_formatTime(endTime!)}';
    }

    return daysText;
  }

  String _formatDate(DateTime date) {
    final weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final weekday = weekdays[date.weekday - 1];
    final day = date.day;
    final month = months[date.month - 1];

    return '$weekday $day $month';
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
  final String? Function(AvailabilityData?)? validator;

  const AvailabilityPicker({
    super.key,
    required this.selectedAvailability,
    this.onAvailabilitySelected,
    this.labelText = 'Disponibilidad para entrega',
    this.prefixIcon = Icons.calendar_month,
    this.isRequired = false,
    this.validator,
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
                color:
                    selectedAvailability == null
                        ? Colors.grey
                        : const Color(0xFF2D8A8A),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color:
                  selectedAvailability == null
                      ? Colors.grey.shade50
                      : isDisabled
                      ? Colors.grey.shade50
                      : const Color(0xFF2D8A8A).withOpacity(0.1),
            ),
            child: Row(
              children: [
                Icon(
                  prefixIcon,
                  color:
                      selectedAvailability == null
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
                          color:
                              selectedAvailability == null
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
                    selectedAvailability == null ? Icons.add : Icons.edit,
                    color:
                        selectedAvailability == null
                            ? Colors.grey
                            : const Color(0xFF2D8A8A),
                  ),
              ],
            ),
          ),
        ),
        if (validator != null)
          Builder(
            builder: (context) {
              final errorMessage = validator!(selectedAvailability);
              if (errorMessage != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 12.0),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
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
  State<_AvailabilityPickerDialog> createState() =>
      _AvailabilityPickerDialogState();
}

class _AvailabilityPickerDialogState extends State<_AvailabilityPickerDialog> {
  late List<String> _selectedDays;
  Map<String, DayTimeRange> _dayTimeRanges = {}; // ✅ Store time for each day

  final List<Map<String, dynamic>> _weekDays = [];
  int _currentWeekOffset =
      0; // ✅ Track which week we're viewing (0 = current week, 1 = next week, -1 = previous week)

  @override
  void initState() {
    super.initState();
    _selectedDays = widget.initialAvailability?.selectedDays ?? [];
    _dayTimeRanges = widget.initialAvailability?.perDayTimes ?? {};
    _buildWeekDays();
  }

  void _buildWeekDays() {
    _weekDays.clear();
    final today = DateTime.now();

    // Calculate the Monday of the target week based on offset
    final targetDate = today.add(Duration(days: _currentWeekOffset * 7));
    final currentWeekday = targetDate.weekday; // 1 = Monday, 7 = Sunday

    // Find Monday of this week
    final monday = targetDate.subtract(Duration(days: currentWeekday - 1));

    final dayNames = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    final shortNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final monthNames = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    // ✅ Always build Mon-Sun (7 days) starting from Monday
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));

      _weekDays.add({
        'full': dayNames[i],
        'short': shortNames[i],
        'dayNumber': date.day,
        'month': monthNames[date.month - 1],
        'year': date.year,
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

              // Recommendation message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Recomendación: Selecciona 2-3 días para mayor flexibilidad',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Days Section with navigation
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
                  Text(
                    _getWeekRangeText(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Week navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous week button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentWeekOffset--;
                        _buildWeekDays();
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                  ),
                  Text(
                    _currentWeekOffset == 0
                        ? 'Esta semana'
                        : _currentWeekOffset > 0
                        ? 'Semana +${_currentWeekOffset}'
                        : 'Semana ${_currentWeekOffset}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  // Next week button
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _currentWeekOffset++;
                        _buildWeekDays();
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                    color: const Color(0xFF2D8A8A),
                    iconSize: 32,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Days Grid with dates (7 days only)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    _weekDays.map((day) {
                      final dayName = day['full'] as String;
                      final date = day['date'] as DateTime;
                      // ✅ Create date-based key for lookup
                      final dateKey =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                      final hasTimeSet = _dayTimeRanges.containsKey(dateKey);
                      final dayNumber = day['dayNumber'];
                      final shortName = day['short'];
                      final month = day['month'];
                      final today = DateTime.now();
                      final isPast = date.isBefore(
                        DateTime(today.year, today.month, today.day),
                      );

                      return GestureDetector(
                        onTap: isPast ? null : () => _selectDayWithTime(day),
                        child: Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isPast
                                    ? Colors.grey.shade200
                                    : hasTimeSet
                                    ? const Color(0xFF2D8A8A)
                                    : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  isPast
                                      ? Colors.grey.shade300
                                      : hasTimeSet
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
                                  color:
                                      isPast
                                          ? Colors.grey.shade400
                                          : hasTimeSet
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayNumber.toString(),
                                style: TextStyle(
                                  color:
                                      isPast
                                          ? Colors.grey.shade400
                                          : hasTimeSet
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                month.toString(),
                                style: TextStyle(
                                  color:
                                      isPast
                                          ? Colors.grey.shade400
                                          : hasTimeSet
                                          ? Colors.white70
                                          : Colors.grey.shade600,
                                  fontSize: 10,
                                ),
                              ),
                              if (hasTimeSet) ...[
                                const SizedBox(height: 2),
                                Icon(
                                  Icons.schedule,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 16),

              // Show selected days with times
              if (_dayTimeRanges.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D8A8A).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2D8A8A).withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D8A8A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.event_available,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Días seleccionados:',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D8A8A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sort entries by date before displaying
                      ...(_dayTimeRanges.entries.toList()..sort(
                            (a, b) => a.value.date.compareTo(b.value.date),
                          ))
                          .map((entry) {
                            final dayTimeRange = entry.value;
                            final monthNames = [
                              'ene',
                              'feb',
                              'mar',
                              'abr',
                              'may',
                              'jun',
                              'jul',
                              'ago',
                              'sep',
                              'oct',
                              'nov',
                              'dic',
                            ];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2D8A8A,
                                  ).withOpacity(0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Day name and date
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dayTimeRange.dayName,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D8A8A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${dayTimeRange.date.day} ${monthNames[dayTimeRange.date.month - 1]}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Time range
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${_formatTime(dayTimeRange.startTime)} - ${_formatTime(dayTimeRange.endTime)}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Remove button
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(20),
                                      onTap: () {
                                        setState(() {
                                          _dayTimeRanges.remove(entry.key);
                                          _selectedDays.remove(
                                            dayTimeRange.dayName,
                                          );
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Icon(
                                          Icons.close,
                                          size: 18,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Confirm Button
              ElevatedButton(
                onPressed:
                    _dayTimeRanges.isNotEmpty
                        ? () {
                          setState(() {
                            _selectedDays = _dayTimeRanges.keys.toList();
                          });
                          widget.onConfirm(
                            AvailabilityData(
                              selectedDays: _selectedDays,
                              startTime: null,
                              endTime: null,
                              perDayTimes: _dayTimeRanges,
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
                child: Text(
                  _dayTimeRanges.isEmpty
                      ? 'Selecciona días y horarios'
                      : 'Confirmar Disponibilidad (${_dayTimeRanges.length} ${_dayTimeRanges.length == 1 ? 'día' : 'días'})',
                  style: const TextStyle(
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

  // ✅ Get week range text showing month range
  String _getWeekRangeText() {
    if (_weekDays.isEmpty) return '';

    final firstDay = _weekDays.first['date'] as DateTime;
    final lastDay = _weekDays.last['date'] as DateTime;
    final monthNames = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    final firstMonth = monthNames[firstDay.month - 1];
    final lastMonth = monthNames[lastDay.month - 1];
    final firstYear = firstDay.year;
    final lastYear = lastDay.year;

    if (firstDay.month == lastDay.month && firstDay.year == lastDay.year) {
      // Same month and year
      return '$firstMonth $firstYear';
    } else if (firstDay.year == lastDay.year) {
      // Different months, same year
      return '$firstMonth - $lastMonth $firstYear';
    } else {
      // Different years
      return '$firstMonth $firstYear - $lastMonth $lastYear';
    }
  }

  // ✅ New method to select a day and set its time
  Future<void> _selectDayWithTime(Map<String, dynamic> day) async {
    final dayName = day['full'] as String;
    final date = day['date'] as DateTime;
    // ✅ Create date-based key (format: yyyy-MM-dd)
    final dateKey =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // If already selected, ask if they want to edit or remove
    if (_dayTimeRanges.containsKey(dateKey)) {
      final action = await showDialog<String>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('$dayName (${date.day}/${date.month})'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hora actual:\n${_formatTime(_dayTimeRanges[dateKey]!.startTime)} - ${_formatTime(_dayTimeRanges[dateKey]!.endTime)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, 'remove'),
                  child: const Text(
                    'Quitar',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'edit'),
                  child: const Text('Cambiar hora'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
      );

      if (action == 'remove') {
        setState(() {
          _dayTimeRanges.remove(dateKey);
          _selectedDays.remove(dayName);
        });
        return;
      } else if (action != 'edit') {
        return;
      }
    }

    // Show time picker dialog
    final result = await showDialog<Map<String, TimeOfDay>>(
      context: context,
      builder:
          (context) => _DayTimePickerDialog(
            dayName: dayName,
            date: date,
            initialStartTime: _dayTimeRanges[dateKey]?.startTime,
            initialEndTime: _dayTimeRanges[dateKey]?.endTime,
          ),
    );

    if (result != null && result['start'] != null && result['end'] != null) {
      setState(() {
        _dayTimeRanges[dateKey] = DayTimeRange(
          dayName: dayName,
          date: date,
          startTime: result['start']!,
          endTime: result['end']!,
        );
        if (!_selectedDays.contains(dayName)) {
          _selectedDays.add(dayName);
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
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
            color:
                time == null ? Colors.grey.shade300 : const Color(0xFF2D8A8A),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              time == null
                  ? Colors.grey.shade50
                  : const Color(0xFF2D8A8A).withOpacity(0.1),
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
                    color:
                        time == null
                            ? Colors.grey.shade400
                            : const Color(0xFF2D8A8A),
                  ),
                ),
                Icon(
                  Icons.access_time,
                  color:
                      time == null
                          ? Colors.grey.shade400
                          : const Color(0xFF2D8A8A),
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

// ✅ New dialog for selecting time for a specific day
class _DayTimePickerDialog extends StatefulWidget {
  final String dayName;
  final DateTime date;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;

  const _DayTimePickerDialog({
    required this.dayName,
    required this.date,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  State<_DayTimePickerDialog> createState() => _DayTimePickerDialogState();
}

class _DayTimePickerDialogState extends State<_DayTimePickerDialog> {
  late TimeOfDay? _startTime;
  late TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime = widget.initialEndTime;
  }

  @override
  Widget build(BuildContext context) {
    final monthNames = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          const Icon(Icons.schedule, color: Color(0xFF2D8A8A), size: 32),
          const SizedBox(height: 8),
          Text(
            widget.dayName,
            style: const TextStyle(
              color: Color(0xFF2D8A8A),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            '${widget.date.day} de ${monthNames[widget.date.month - 1]}',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Selecciona el horario disponible:',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          _TimePickerButton(
            label: 'Hora de inicio',
            time: _startTime,
            onTap: () => _selectTime(true),
          ),
          const SizedBox(height: 12),
          _TimePickerButton(
            label: 'Hora de fin',
            time: _endTime,
            onTap: () => _selectTime(false),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed:
              _startTime != null && _endTime != null
                  ? () {
                    Navigator.pop<Map<String, TimeOfDay>>(context, {
                      'start': _startTime!,
                      'end': _endTime!,
                    });
                  }
                  : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D8A8A),
            disabledBackgroundColor: Colors.grey.shade300,
          ),
          child: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
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
