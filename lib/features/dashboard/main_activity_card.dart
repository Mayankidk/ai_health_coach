import 'package:flutter/material.dart';

class MainActivityCard extends StatelessWidget {
  final int steps;
  final int goal;
  final double distanceKm;
  final double calories;
  final VoidCallback? onTap;

  const MainActivityCard({
    super.key,
    required this.steps,
    this.goal = 10000,
    required this.distanceKm,
    required this.calories,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha(45),
              blurRadius: 18,
              spreadRadius: -2,
              offset: Offset.zero,
            ),
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 12,
              spreadRadius: -2,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 220,
                          height: 220,
                          child: CustomPaint(
                            painter: GoalRingPainter(
                              progress: (steps / goal).clamp(0.0, 1.0),
                              color: Colors.blueAccent,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              steps.toString(),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              "steps",
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.withAlpha(15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Goal: ${goal ~/ 1000}k",
                                style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetric(
                        Icons.map_rounded,
                        "${distanceKm.toStringAsFixed(2)} km",
                        "Distance",
                        Colors.blue,
                      ),
                      _buildMetric(
                        Icons.local_fire_department_rounded,
                        "${calories.toInt()} kcal",
                        "Calories",
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(IconData icon, String value, String label, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GoalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  GoalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;

    // Background Ring
    final bgPaint = Paint()
      ..color = const Color(0xFFF5F5F5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - (strokeWidth / 2), bgPaint);

    // Progress Line
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Outer Glow
    final glowPaint = Paint()
      ..color = color.withAlpha(50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final rect = Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2));
    
    canvas.drawArc(
      rect,
      -1.5708,
      2 * 3.14159 * progress,
      false,
      glowPaint,
    );

    canvas.drawArc(
      rect,
      -1.5708,
      2 * 3.14159 * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant GoalRingPainter oldDelegate) => 
      oldDelegate.progress != progress;
}
