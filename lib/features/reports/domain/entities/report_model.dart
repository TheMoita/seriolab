import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Target entity types eligible for moderation reports.
enum ReportTargetType {
  comment('comment'),
  userProfile('user_profile');

  const ReportTargetType(this.value);
  final String value;

  static ReportTargetType fromString(String? val) {
    if (val == 'user_profile') return ReportTargetType.userProfile;
    return ReportTargetType.comment;
  }
}

/// Moderation review status of a submitted report.
enum ReportStatus {
  pending('pending'),
  resolved('resolved'),
  dismissed('dismissed');

  const ReportStatus(this.value);
  final String value;

  static ReportStatus fromString(String? val) {
    return ReportStatus.values.firstWhere(
      (s) => s.value == val,
      orElse: () => ReportStatus.pending,
    );
  }
}

/// Model representing a moderation report for offensive comments or user profiles.
@immutable
class ReportModel {
  const ReportModel({
    required this.id,
    required this.reporterUserId,
    required this.targetType,
    required this.targetId,
    required this.reportedUserId,
    required this.reason,
    this.details = '',
    required this.createdAt,
    this.status = ReportStatus.pending,
  });

  /// Unique identifier of the report.
  final String id;

  /// UID of the user filing the report.
  final String reporterUserId;

  /// Type of target being flagged ('comment' or 'user_profile').
  final ReportTargetType targetType;

  /// Target identifier (review ID for comments, user UID for profiles).
  final String targetId;

  /// UID of the author of the reported content or profile.
  final String reportedUserId;

  /// Selected reason category.
  final String reason;

  /// Optional contextual details provided by the reporter.
  final String details;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Moderation status.
  final ReportStatus status;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ReportModel(
      id: json['id'] as String? ?? '',
      reporterUserId: json['reporterUserId'] as String? ?? '',
      targetType: ReportTargetType.fromString(json['targetType'] as String?),
      targetId: json['targetId'] as String? ?? '',
      reportedUserId: json['reportedUserId'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String? ?? '',
      createdAt: parseDate(json['createdAt']),
      status: ReportStatus.fromString(json['status'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterUserId': reporterUserId,
        'targetType': targetType.value,
        'targetId': targetId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details,
        'createdAt': createdAt.toIso8601String(),
        'status': status.value,
      };

  Map<String, dynamic> toFirestore() => {
        'id': id,
        'reporterUserId': reporterUserId,
        'targetType': targetType.value,
        'targetId': targetId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'details': details,
        'createdAt': FieldValue.serverTimestamp(),
        'status': status.value,
      };

  ReportModel copyWith({
    String? id,
    String? reporterUserId,
    ReportTargetType? targetType,
    String? targetId,
    String? reportedUserId,
    String? reason,
    String? details,
    DateTime? createdAt,
    ReportStatus? status,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      reportedUserId: reportedUserId ?? this.reportedUserId,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
