import 'package:flutter/material.dart';

class StepGoalEditor extends StatelessWidget {
  final int currentGoal;
  final ValueChanged<int> onGoalChanged;

  const StepGoalEditor({
    super.key,
    required this.currentGoal,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Daily Step Goal",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                "${currentGoal ~/ 1000}k steps",
                style: const TextStyle(
                  color: Color(0xFF006B6B),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 0), // Minimal gap
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: const Color(0xFF006B6B),
              thumbColor: const Color(0xFF006B6B),
              overlayColor: const Color(0xFF006B6B).withAlpha(30),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0), // Flutter doesn't allow negative padding
              child: Slider(
                value: currentGoal.toDouble(),
                min: 2000,
                max: 20000,
                divisions: 18,
                onChanged: (val) => onGoalChanged(val.toInt()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
