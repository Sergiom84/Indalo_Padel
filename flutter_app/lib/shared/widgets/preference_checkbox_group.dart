import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../utils/player_preferences.dart';

class PreferenceCheckboxGroup extends StatefulWidget {
  final String title;
  final List<PreferenceOption> options;
  final List<String> selectedValues;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  const PreferenceCheckboxGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<PreferenceCheckboxGroup> createState() =>
      _PreferenceCheckboxGroupState();
}

class _PreferenceCheckboxGroupState extends State<PreferenceCheckboxGroup> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedSet = widget.selectedValues.toSet();
    final selectedLabels =
        PlayerPreferenceCatalog.labelsForValues(widget.selectedValues);
    final summary = selectedLabels.isEmpty
        ? 'Selecciona una o varias opciones'
        : selectedLabels.join(', ');
    final borderColor = _expanded ? AppColors.primary : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title.toUpperCase(),
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: _expanded ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: widget.enabled
                      ? () => setState(() => _expanded = !_expanded)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            summary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selectedLabels.isEmpty
                                  ? AppColors.muted
                                  : Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.keyboard_arrow_down,
                            color: widget.enabled
                                ? AppColors.muted
                                : AppColors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 180),
                  crossFadeState: _expanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      const Divider(height: 1, color: AppColors.border),
                      for (var index = 0;
                          index < widget.options.length;
                          index++) ...[
                        CheckboxListTile(
                          value:
                              selectedSet.contains(widget.options[index].value),
                          onChanged: widget.enabled
                              ? (_) => widget.onChanged(
                                    _toggleValue(
                                      widget.selectedValues,
                                      widget.options[index].value,
                                    ),
                                  )
                              : null,
                          activeColor: AppColors.primary,
                          checkColor: AppColors.dark,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          title: Text(
                            widget.options[index].label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (index < widget.options.length - 1)
                          const Divider(
                            height: 1,
                            color: AppColors.border,
                          ),
                      ],
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  sizeCurve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<String> _toggleValue(List<String> currentValues, String value) {
    final nextValues = [...currentValues];
    if (nextValues.contains(value)) {
      nextValues.remove(value);
    } else {
      nextValues.add(value);
    }

    return PlayerPreferenceCatalog.orderedValues(nextValues, widget.options);
  }
}
