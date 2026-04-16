import 'package:flutter/material.dart';
import 'dart:math' as math;

enum ActivityDataType { steps, distance, calories, sleep, hrv }


class ActivityChart extends StatefulWidget {
  final List<num> data;
  final num goal;
  final ActivityDataType type;

  const ActivityChart({
    super.key, 
    required this.data,
    required this.goal,
    this.type = ActivityDataType.steps,
  });

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _ActivityChartState extends State<ActivityChart> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatValue(num value) {
    if (widget.type == ActivityDataType.steps) {
      return value.toInt().toString();
    } else if (widget.type == ActivityDataType.distance) {
      return "${value.toStringAsFixed(2)} km";
    } else if (widget.type == ActivityDataType.sleep) {
      final hours = value ~/ 60;
      final mins = (value % 60).toInt();
      return "${hours}h ${mins}m";
    } else if (widget.type == ActivityDataType.hrv) {
      return "${value.toInt()} ms";
    } else {
      return "${value.toInt()} kcal";
    }
  }


  String _getLabel(num value) {
    if (widget.type == ActivityDataType.steps) {
      return value == 0 ? "0" : "${(value ~/ 1000)}k";
    } else if (widget.type == ActivityDataType.distance) {
      return value == 0 ? "0" : "${value.toStringAsFixed(1)}k";
    } else if (widget.type == ActivityDataType.sleep) {
      return "${(value / 60).toStringAsFixed(0)}h";
    } else if (widget.type == ActivityDataType.hrv) {
      return "${value.toInt()}";
    } else {
      return value == 0 ? "0" : "${(value ~/ 100)}h"; // 'h' for hundreds? Maybe just the number
    }
  }


  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    num maxVal = widget.data.isEmpty ? 0 : widget.data[0];
    for (final v in widget.data) {
      if (v > maxVal) maxVal = v;
    }
    final effectiveMax = math.max(maxVal, widget.goal);
    
    // Calculate a "nice" chart max and interval based on type
    double interval;
    if (widget.type == ActivityDataType.steps) {
      interval = 2000;
    } else if (widget.type == ActivityDataType.distance) {
      interval = 2.0;
    } else if (widget.type == ActivityDataType.sleep) {
      interval = 120; // 2 hours
    } else if (widget.type == ActivityDataType.hrv) {
      interval = 20.0;
    } else {
      interval = 500.0;
    }


    double chartMax = ((effectiveMax / interval).ceil() * interval).toDouble();
    if (chartMax == effectiveMax) chartMax += interval;
    if (chartMax <= 0) chartMax = interval * 4;

    String title;
    Color accentColor;
    if (widget.type == ActivityDataType.steps) {
      title = "Weekly Steps";
      accentColor = const Color(0xFF006B6B);
    } else if (widget.type == ActivityDataType.distance) {
      title = "Weekly Distance";
      accentColor = Colors.blue;
    } else if (widget.type == ActivityDataType.sleep) {
      title = "Weekly Sleep";
      accentColor = Colors.lightBlue;
    } else if (widget.type == ActivityDataType.hrv) {
      title = "Weekly HRV";
      accentColor = Colors.red;
    } else {

      title = "Weekly Calories";
      accentColor = Colors.orange;
    }


    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            //offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "Tap bars for details",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (widget.type == ActivityDataType.steps)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Goal: ${_formatGoal(widget.goal)}",
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 38),
          
          LayoutBuilder(
            builder: (context, constraints) {
              const labelWidth = 50.0;
              final chartWidth = constraints.maxWidth - labelWidth;
              
              final gridLineValues = <double>[];
              for (double v = 0; v <= chartMax; v += interval) {
                gridLineValues.add(v);
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // 1. Guidelines
                  ...gridLineValues.map((value) {
                    final x = labelWidth + (chartWidth * (value / chartMax));
                    final label = _getGridLabel(value);
                    
                    return Positioned(
                      left: x,
                      top: 0,
                      bottom: 0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(width: 1, color: Colors.grey[50]),
                          Positioned(
                            left: -15,
                            top: -24,
                            child: SizedBox(
                              width: 30,
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),

                  // 2. Goal Line
                  if (widget.type == ActivityDataType.steps)
                    Positioned(
                      left: labelWidth + (widget.goal / chartMax) * chartWidth,
                      top: -8,
                      bottom: -8,
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.25),
                        ),
                      ),
                    ),

                  // 3. The Bars
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.data.length, (index) {
                      final val = widget.data[index];
                      final isToday = index == widget.data.length - 1;
                      final date = DateTime.now().subtract(Duration(days: widget.data.length - 1 - index));
                      final dayLabel = _getDayLabel(date);
                      final isSelected = _selectedIndex == index;
                      final hitGoal = val >= widget.goal;
                      
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() {
                            _selectedIndex = (_selectedIndex == index) ? null : index;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: labelWidth,
                                child: Text(
                                  dayLabel,
                                  style: TextStyle(
                                    color: isToday ? accentColor : Colors.grey[500],
                                    fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF9F9F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    ScaleTransition(
                                      scale: _animation,
                                      alignment: Alignment.centerLeft,
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: isSelected ? 16 : (isToday ? 14 : 10),
                                        width: chartMax > 0 ? (val / chartMax) * chartWidth : 0,
                                        decoration: BoxDecoration(
                                          color: hitGoal && widget.type == ActivityDataType.steps
                                            ? const Color(0xFF00BFA5) 
                                            : accentColor.withOpacity(isToday ? 1.0 : 0.6),
                                          borderRadius: BorderRadius.circular(8),

                                          boxShadow: const [],



                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        left: math.max(0.0, (val / chartMax * chartWidth) - 40),
                                        top: -30,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1A1A1A),
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                          ),
                                          child: Text(
                                            _formatValue(val),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatGoal(num goal) {
    if (widget.type == ActivityDataType.steps) return "${goal ~/ 1000}k";
    if (widget.type == ActivityDataType.distance) return "${goal.toStringAsFixed(1)} km";
    if (widget.type == ActivityDataType.sleep) return "${goal ~/ 60}h";
    if (widget.type == ActivityDataType.hrv) return "${goal.toInt()} ms";
    return "${goal.toInt()} kcal";
  }


  String _getGridLabel(num value) {
    if (widget.type == ActivityDataType.steps) {
      return value == 0 ? "0" : "${value ~/ 1000}k";
    }
    if (widget.type == ActivityDataType.distance) {
      return value == 0 ? "0" : value.toStringAsFixed(1);
    }
    if (widget.type == ActivityDataType.sleep) {
      return "${(value / 60).toStringAsFixed(0)}h";
    }
    if (widget.type == ActivityDataType.hrv) {
      return value.toInt().toString();
    }
    return value.toInt().toString();
  }


  String _getDayLabel(DateTime date) {
    final days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    return days[date.weekday % 7];
  }
}
