import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/repositories/report_repository.dart';

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  final trackingRepo = ref.watch(trackingRepositoryProvider);
  FirebaseFirestore? firestore;
  if (Firebase.apps.isNotEmpty) {
    try {
      firestore = FirebaseFirestore.instance;
    } catch (_) {}
  }

  return ReportRepositoryImpl(
    firestore: firestore,
    trackingRepository: trackingRepo,
  );
});
