import '../entities/report_model.dart';

abstract interface class ReportRepository {
  /// Submits a moderation report for offensive comments or user profiles.
  Future<void> submitReport(ReportModel report);
}
