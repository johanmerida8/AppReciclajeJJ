class Deliver {
  int? id;
  String? address;
  double? lat;
  double? lng;
  // DateTime? pickUpDate;
  int? state;

  Deliver({
    this.id,
    this.address,
    this.lat,
    this.lng,
    // this.pickUpDate,
    this.state,
  });

  factory Deliver.fromMap(Map<String, dynamic> map) {
    return Deliver(
      id: map['idDeliver'] as int?,
      address: map['address'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      // pickUpDate: map['datePickUp'] != null
      //     ? DateTime.parse(map['datePickUp'] as String)
      //     : null,
      state: map['state'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'lat': lat,
      'lng': lng,
      // 'datePickUp': pickUpDate?.toIso8601String(),
      'state': state ?? 1, // Por defecto, estado activo
    };
  }
}