import '/model/admin/cycle_star_model.dart';

// Clase para los tiers
class CarryOverTier {
  final int positionStart;
  final int positionEnd;
  final int deliveries;
  final int stars;
  final int points;

  CarryOverTier({
    required this.positionStart,
    required this.positionEnd,
    required this.deliveries,
    required this.stars,
    required this.points,
  });
}

// Función para generar los tiers
List<CarryOverTier> generateCarryOverTiers({
  required int topCount,
  required List<CycleStarModel> starValues,
}) {
  if (topCount <= 0) return [];

  // Crear mapa de puntos por estrellas para acceso rápido
  final starPoints = {for (var s in starValues) s.stars: s.points};

  int tier1Size = topCount == 1 ? 1 : (topCount >= 3 ? (topCount * 0.2).ceil() : 1);
  int tier2Size = topCount >= 3 ? (topCount * 0.4).ceil() : (topCount == 2 ? 1 : 0);
  int tier3Size = topCount - tier1Size - tier2Size;

  List<CarryOverTier> tiers = [];

  // Tier 1
  if (tier1Size > 0) {
    tiers.add(CarryOverTier(
      positionStart: 1,
      positionEnd: tier1Size,
      deliveries: topCount == 1 ? 3 : 2,
      stars: 5,
      points: (topCount == 1 ? 3 : 2) * (starPoints[5] ?? 0),
    ));
  }

  // Tier 2
  if (tier2Size > 0) {
    tiers.add(CarryOverTier(
      positionStart: tier1Size + 1,
      positionEnd: tier1Size + tier2Size,
      deliveries: 1,
      stars: 5,
      points: 1 * (starPoints[5] ?? 0),
    ));
  }

  // Tier 3
  if (tier3Size > 0) {
    tiers.add(CarryOverTier(
      positionStart: tier1Size + tier2Size + 1,
      positionEnd: topCount,
      deliveries: 1,
      stars: 3,
      points: 1 * (starPoints[3] ?? 0),
    ));
  }

  return tiers;
}
