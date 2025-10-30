// class CompanyData {
//   final int idUser;
//   final String names;
//   final String email;
//   final int? idCompany;
//   final String? nameCompany;
//   final int? adminUserId;

//   CompanyData({
//     required this.idUser,
//     required this.names,
//     required this.email,
//     this.idCompany,
//     this.nameCompany,
//     this.adminUserId,
//   });

//   /// Convert this object into a JSON map
//   Map<String, dynamic> toJson() {
//     return {
//       'idUser': idUser,
//       'names': names,
//       'email': email,
//       'idCompany': idCompany,
//       'nameCompany': nameCompany,
//       'adminUserId': adminUserId,
//     };
//   }

//   /// Create a CompanyData instance from a JSON map
//   factory CompanyData.fromJson(Map<String, dynamic> json) {
//     return CompanyData(
//       idUser: json['idUser'] is int
//           ? json['idUser']
//           : int.tryParse(json['idUser'].toString()) ?? 0,
//       names: json['names'] ?? '',
//       email: json['email'] ?? '',
//       idCompany: json['idCompany'] == null
//           ? null
//           : (json['idCompany'] is int
//               ? json['idCompany']
//               : int.tryParse(json['idCompany'].toString())),
//       nameCompany: json['nameCompany'],
//       adminUserId: json['adminUserId'] == null
//           ? null
//           : (json['adminUserId'] is int
//               ? json['adminUserId']
//               : int.tryParse(json['adminUserId'].toString())),
//     );
//   }

//   /// Copy this object with optional new values (useful for updates)
//   CompanyData copyWith({
//     int? idUser,
//     String? names,
//     String? email,
//     int? idCompany,
//     String? nameCompany,
//     int? adminUserId,
//   }) {
//     return CompanyData(
//       idUser: idUser ?? this.idUser,
//       names: names ?? this.names,
//       email: email ?? this.email,
//       idCompany: idCompany ?? this.idCompany,
//       nameCompany: nameCompany ?? this.nameCompany,
//       adminUserId: adminUserId ?? this.adminUserId,
//     );
//   }
// }
