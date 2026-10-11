import 'package:flutter/material.dart';

/// Standardized single drag handle for all modal bottom sheets across Seriolab.
///
/// Ensures a consistent, discreet soft-gray (#4B5563) indicator centered at the
/// top of each bottom sheet, preventing duplicate handles and visual clutter.
class ModalDragHandle extends StatelessWidget {
  const ModalDragHandle({
    super.key,
    this.topPadding = 12.0,
    this.bottomPadding = 12.0,
    this.width = 38.0,
    this.height = 4.0,
    this.color = const Color(0xFF4B5563),
  });

  final double topPadding;
  final double bottomPadding;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width,
        height: height,
        margin: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
