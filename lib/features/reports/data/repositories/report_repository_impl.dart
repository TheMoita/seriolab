import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../domain/entities/report_model.dart';
import '../../domain/repositories/report_repository.dart';

class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({
    this.firestore,
    this.trackingRepository,
  });

  final FirebaseFirestore? firestore;
  final TrackingRepository? trackingRepository;

  @override
  Future<void> submitReport(ReportModel report) async {
    // 1. Try persisting to Firestore under collection 'reports/{reportId}'
    try {
      final fs = firestore ?? FirebaseFirestore.instance;
      await fs
          .collection('reports')
          .doc(report.id)
          .set(report.toFirestore(), SetOptions(merge: true));
    } catch (_) {
      // Allows graceful handling when offline or without Firebase config
    }

    // 2. Persist to local metadata cache if trackingRepository is available
    if (trackingRepository != null) {
      try {
        final key = 'report_${report.id}';
        await trackingRepository!.writeMeta(key, jsonEncode(report.toJson()));
      } catch (_) {}
    }
  }
}
