import 'package:flutter/material.dart';

class FoodTile extends StatelessWidget {
  final String keyName;
  final String title;
  final String time;
  final List<dynamic> items;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const FoodTile({
    super.key,
    required this.keyName,
    required this.title,
    required this.time,
    required this.items,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = enabled ? Colors.white : Colors.grey.shade200;
    final borderColor = enabled ? Colors.grey.shade200 : Colors.grey.shade300;
    final titleColor = enabled ? const Color(0xFF2E3192) : Colors.grey.shade500;
    final timeColor = enabled ? Colors.grey : Colors.grey.shade500;
    final itemTitleColor = enabled ? Colors.black : Colors.grey.shade500;
    final itemDescriptionColor = enabled ? Colors.grey : Colors.grey.shade400;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: enabled
            ? const [BoxShadow(color: Colors.black12, blurRadius: 4)]
            : const [],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: enabled ? checked : false,
            fillColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return Colors.grey.shade200;
              }
              return Colors.white;
            }),
            checkColor: const Color(0xFF29ABE2),
            onChanged: enabled ? (value) => onChanged(value ?? false) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(color: timeColor, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: items.map<Widget>((item) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item["name"],
                          style: TextStyle(
                            color: itemTitleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          item["description"],
                          style: TextStyle(
                            color: itemDescriptionColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
