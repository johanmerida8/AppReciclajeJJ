import 'package:home_widget/home_widget.dart';

class DistribuidorWidgetController {
  static Future<void> actualizar({
    required int puntos,
    required int ranking,
  }) async {
    await HomeWidget.saveWidgetData<int>('puntos', puntos);
    await HomeWidget.saveWidgetData<int>('ranking', ranking);

    await HomeWidget.updateWidget(
      name: 'DistribuidorWidget',
      androidName: 'DistribuidorWidget',
    );
  }
}
