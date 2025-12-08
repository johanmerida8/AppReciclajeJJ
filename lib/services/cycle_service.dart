// import 'package:flutter/foundation.dart';
// import 'package:reciclaje_app/database/cycle_database.dart';

// /// Service to monitor cycle status and notify listeners of changes
// class CycleService extends ChangeNotifier {
//   static final CycleService _instance = CycleService._internal();
//   factory CycleService() => _instance;
//   CycleService._internal();

//   final _cycleDatabase = CycleDatabase();
  
//   bool _isCycleExpired = false;
//   int? _daysRemaining;
//   String? _cycleName;
//   DateTime? _cycleEndDate;
  
//   bool get isCycleExpired => _isCycleExpired;
//   int? get daysRemaining => _daysRemaining;
//   String? get cycleName => _cycleName;
//   DateTime? get cycleEndDate => _cycleEndDate;

//   /// Check if the current cycle has expired
//   Future<void> checkCycleStatus() async {
//     try {
//       final activeCycle = await _cycleDatabase.getActiveCycle();
      
//       if (activeCycle == null) {
//         _isCycleExpired = true;
//         _daysRemaining = null;
//         _cycleName = null;
//         _cycleEndDate = null;
//         print('⚠️ No active cycle found');
//         notifyListeners();
//         return;
//       }

//       final endDateStr = activeCycle['endDate'] as String?;
//       final cycleState = activeCycle['state'] as int?;
//       _cycleName = activeCycle['name'] as String?;

//       if (endDateStr != null) {
//         _cycleEndDate = DateTime.parse(endDateStr);
//         final now = DateTime.now();
//         final difference = _cycleEndDate!.difference(DateTime(now.year, now.month, now.day));
//         final daysLeft = difference.inDays + 1;

//         if (daysLeft <= 0 || cycleState == 0) {
//           _isCycleExpired = true;
//           _daysRemaining = null;
//           print('⚠️ Cycle expired: $_cycleName (End date: $_cycleEndDate)');
//         } else {
//           _isCycleExpired = false;
//           _daysRemaining = daysLeft;
//           print('✅ Cycle active: $_cycleName ($daysLeft days remaining)');
//         }
//       } else {
//         _isCycleExpired = false;
//         _daysRemaining = null;
//       }

//       notifyListeners();
//     } catch (e) {
//       print('❌ Error checking cycle status: $e');
//       _isCycleExpired = false;
//       _daysRemaining = null;
//       notifyListeners();
//     }
//   }

//   /// Reset cycle service state
//   void reset() {
//     _isCycleExpired = false;
//     _daysRemaining = null;
//     _cycleName = null;
//     _cycleEndDate = null;
//     notifyListeners();
//   }
// }
