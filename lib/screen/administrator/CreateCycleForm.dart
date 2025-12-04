import 'package:flutter/material.dart';
import 'package:reciclaje_app/components/admin/TopPointsWidget.dart';
import '/theme/app_colors.dart';
import '/theme/app_spacing.dart';
import '/theme/app_text_styles.dart';
import '/components/admin/points_calculator.dart'; // generateCarryOverTiers y CarryOverTier
import '/model/admin/cycle_star_model.dart';
import '/model/admin/cycle_model.dart';
import '/database/admin/cycleList_db.dart';

class CreateCycleForm extends StatefulWidget {
  final List<CycleModel> existingCycles;
  const CreateCycleForm({super.key, required this.existingCycles});

  @override
  State<CreateCycleForm> createState() => _CreateCycleFormState();
}

class _CreateCycleFormState extends State<CreateCycleForm> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _topQuantityController = TextEditingController();

  // Controladores de puntos por estrella
  final Map<int, TextEditingController> _starControllers = {
    1: TextEditingController(),
    2: TextEditingController(),
    3: TextEditingController(),
    4: TextEditingController(),
    5: TextEditingController(),
  };

  DateTime? _startDate;
  DateTime? _endDate;

  List<CycleStarModel> _starValues = [];
  List<CarryOverTier> _tiers = [];

  // Rangos bloqueados desde los ciclos existentes
  late final List<DateTimeRange> disabledRanges;

  // Acceso a la base de datos
  final CycleListDB _cycleListDB = CycleListDB();

  @override
  void initState() {
    super.initState();
    disabledRanges =
        widget.existingCycles
            .where((cycle) => cycle.state == 1)
            .map(
              (cycle) =>
                  DateTimeRange(start: cycle.startDate, end: cycle.endDate),
            )
            .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _topQuantityController.dispose();
    for (var c in _starControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Encuentra la siguiente fecha disponible que no esté en rangos bloqueados
  DateTime findNextAvailableDate(DateTime date) {
    DateTime d = date;

    while (true) {
      bool disabled = false;
      for (final range in disabledRanges) {
        if (d.isAfter(range.start.subtract(const Duration(days: 1))) &&
            d.isBefore(range.end.add(const Duration(days: 1)))) {
          disabled = true;
          d = range.end.add(const Duration(days: 1));
          break;
        }
      }

      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      if (d.isBefore(today)) {
        d = today;
        continue;
      }

      if (!disabled) return d;
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateTime.now();
    DateTime initial =
        isStart ? (_startDate ?? today) : (_endDate ?? (_startDate ?? today));
    initial = findNextAvailableDate(initial);

    bool isDisabled(DateTime day) {
      for (final range in disabledRanges) {
        if (day.isAfter(range.start.subtract(const Duration(days: 1))) &&
            day.isBefore(range.end.add(const Duration(days: 1)))) {
          return true;
        }
      }
      return false;
    }

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: findNextAvailableDate(today),
      lastDate: DateTime(2090),
      selectableDayPredicate: (day) {
        if (isDisabled(day)) return false;
        if (!isStart && _startDate != null && day.isBefore(_startDate!))
          return false;
        return true;
      },
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(date)) _endDate = null;
        } else {
          _endDate = date;
        }
      });
    }
  }

  void _updateTiers() {
    final topCount = int.tryParse(_topQuantityController.text) ?? 0;

    _starValues = List.generate(
      5,
      (index) => CycleStarModel(
        stars: index + 1,
        points: int.tryParse(_starControllers[index + 1]!.text) ?? 0,
      ),
    );

    _tiers = generateCarryOverTiers(
      topCount: topCount,
      starValues: _starValues,
    );
  }

  bool _validateDates() {
    if (_startDate == null || _endDate == null) return false;
    return !_endDate!.isBefore(_startDate!);
  }

  Future<void> _saveCycle() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Seleccione ambas fechas.")));
      return;
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    if (_startDate!.isBefore(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("La fecha de inicio no puede ser anterior a hoy."),
        ),
      );
      return;
    }

    if (!_validateDates()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "La fecha final debe ser mayor o igual a la fecha de inicio.",
          ),
        ),
      );
      return;
    }

    setState(() {}); // opcional: mostrar loading

    final top = int.tryParse(_topQuantityController.text.trim()) ?? 0;

    // 1️⃣ Crear ciclo
    final createdId = await _cycleListDB.createCycle(
      name: _nameController.text.trim(),
      startDate: _startDate!,
      endDate: _endDate!,
      topQuantity: top,
    );

    if (createdId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudo crear: hay solapamiento con otro ciclo"),
        ),
      );
      return;
    }

    // 2️⃣ Insertar valores de estrellas del formulario
    final starData =
        _starValues
            .map(
              (s) => {
                'cycleID': createdId,
                'stars': s.stars,
                'points': s.points,
              },
            )
            .toList();

    try {
      await _cycleListDB.client.from('starValue').insert(starData);
    } catch (e) {
      print('❌ Error insertando valores de estrellas: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Ciclo creado, pero no se guardaron los puntos de estrellas",
          ),
        ),
      );
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Ciclo creado correctamente")));

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    _updateTiers(); // recalcula cada vez que se rebuild

    return Padding(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + AppSpacing.paddingbody,
        top: AppSpacing.paddingbody,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nombre
              //Text("Nombre del ciclo", style: AppTextStyles.textSmall),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: inputDecoration.copyWith(hintText: "Ingrese el nombre"),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return "Ingrese un nombre válido";
                  if (value.trim().length < 3)
                    return "Debe tener al menos 3 caracteres";
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Fechas lado a lado
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //Text("Fecha inicio", style: AppTextStyles.textSmall),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed: () => _pickDate(isStart: true),
                          child: Text(
                            _startDate == null
                                ? "Fecha inicio"
                                : "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}",
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        //Text("Fecha final", style: AppTextStyles.textSmall),
                        const SizedBox(height: 6),
                        OutlinedButton(
                          onPressed:
                              _startDate == null
                                  ? null
                                  : () => _pickDate(isStart: false),
                          child: Text(
                            _endDate == null
                                ? "fecha final"
                                : "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}",
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Puntos por estrella
              //Text("Puntos por estrella", style: AppTextStyles.textSmall),
              const SizedBox(height: 6),
              Column(
                children: List.generate(5, (index) {
                  final star = 5 - index;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Row(
                          children: List.generate(5, (i) {
                            return Icon(
                              i < star ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            );
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _starControllers[star],
                            keyboardType: TextInputType.number,
                            decoration: inputDecoration.copyWith(hintText: "Puntos"),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return "Ingrese un valor";
                              final n = int.tryParse(value);
                              if (n == null || n < 0) return "Debe ser 0 o más";
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text("pts", style: AppTextStyles.textMedium),
                      ],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Top Quantity
              //Text("Top N usuarios", style: AppTextStyles.textSmall),
              const SizedBox(height: 6),
              TextFormField(
                controller: _topQuantityController,
                keyboardType: TextInputType.number,
                decoration: inputDecoration.copyWith(hintText: "Número de usuarios top"),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Ingrese un número";
                  final n = int.tryParse(value);
                  if (n == null || n <= 0) return "Debe ser mayor a 0";
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Vista previa de distribución de puntos
              TopPointsWidget(
                title:
                    "Puntos Iniciales (Top ${_topQuantityController.text.isEmpty ? 0 : _topQuantityController.text})",
                tiers: _tiers,
              ),

              const SizedBox(height: 30),

              // Botón Crear
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveCycle,
                  child: const Text("Crear Ciclo"),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  final inputDecoration = InputDecoration(
  filled: true,
  fillColor: AppColors.fondoGrisClaro, // Fondo gris
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14), // radio más grande
    borderSide: BorderSide.none, // sin borde por defecto
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(14), // mismo radio
    borderSide: BorderSide(
      color: Colors.blue, // color del borde al enfocar
      width: 2, // grosor del borde
    ),
  ),
  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
);

}
