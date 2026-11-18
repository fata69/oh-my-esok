import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'motion.dart';
import 'theme.dart';

Future<TimeOfDay?> showTimePickerSheet(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    sheetAnimationStyle: EsokMotion.presentation(context),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x5214120E),
    builder: (context) => TimePickerSheet(initial: initial),
  );
}

class TimePickerSheet extends StatefulWidget {
  const TimePickerSheet({super.key, required this.initial});

  final TimeOfDay initial;

  @override
  State<TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<TimePickerSheet> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _selectHour(int value) {
    if (_hour == value) return;
    HapticFeedback.selectionClick();
    setState(() => _hour = value);
  }

  void _selectMinute(int value) {
    if (_minute == value) return;
    HapticFeedback.selectionClick();
    setState(() => _minute = value);
  }

  void _setNow() {
    final now = DateTime.now();
    HapticFeedback.selectionClick();
    setState(() {
      _hour = now.hour;
      _minute = now.minute;
    });
    if (EsokMotion.reduced(context)) {
      _hourController.jumpToItem(now.hour);
      _minuteController.jumpToItem(now.minute);
      return;
    }
    _hourController.animateToItem(
      now.hour,
      duration: EsokMotion.enter,
      curve: EsokMotion.settle,
    );
    _minuteController.animateToItem(
      now.minute,
      duration: EsokMotion.enter,
      curve: EsokMotion.settle,
    );
  }

  String get _preview =>
      '${_hour.toString().padLeft(2, '0')}.${_minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EsokColors.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: EsokColors.handle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pilih jam',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.01,
                        color: EsokColors.ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _setNow,
                    style: TextButton.styleFrom(
                      foregroundColor: EsokColors.accent,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Sekarang'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: EsokColors.muted,
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              Text(
                _preview,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  letterSpacing: -0.03,
                  color: EsokColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Geser jam dan menit',
                style: TextStyle(fontSize: 11.5, color: EsokColors.muted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 48,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: EsokColors.soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.symmetric(
                          horizontal: BorderSide(color: EsokColors.line),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeWheel(
                            controller: _hourController,
                            count: 24,
                            selected: _hour,
                            semanticsLabel: 'Jam',
                            onChanged: _selectHour,
                          ),
                        ),
                        SizedBox(
                          width: 20,
                          child: Center(
                            child: Text(
                              ':',
                              style: TextStyle(
                                fontSize: 26,
                                color: EsokColors.muted,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _TimeWheel(
                            controller: _minuteController,
                            count: 60,
                            selected: _minute,
                            semanticsLabel: 'Menit',
                            onChanged: _selectMinute,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: EsokColors.muted,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Batal'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(TimeOfDay(hour: _hour, minute: _minute)),
                        style: FilledButton.styleFrom(
                          backgroundColor: EsokColors.accent,
                          foregroundColor: EsokColors.fabText,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('Pilih'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  const _TimeWheel({
    required this.controller,
    required this.count,
    required this.selected,
    required this.semanticsLabel,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String semanticsLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 46,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.002,
        diameterRatio: 1.8,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) {
            final isSelected = index == selected;
            return Center(
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 24,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? EsokColors.ink : EsokColors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
