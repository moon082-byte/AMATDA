import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/room_avatar.dart';
import 'field_label.dart';

/// 업무방 종류(그룹/개인/채널)와 멤버 인원수 입력
class RoomInfoFields extends StatefulWidget {
  final TelegramRoomType type;
  final int memberCount;
  final ValueChanged<TelegramRoomType> onTypeChanged;
  final ValueChanged<int> onMemberCountChanged;

  const RoomInfoFields({
    super.key,
    required this.type,
    required this.memberCount,
    required this.onTypeChanged,
    required this.onMemberCountChanged,
  });

  @override
  State<RoomInfoFields> createState() => _RoomInfoFieldsState();
}

class _RoomInfoFieldsState extends State<RoomInfoFields> {
  static const _types = [
    TelegramRoomType.group,
    TelegramRoomType.private,
    TelegramRoomType.channel,
  ];
  late final _count = TextEditingController(text: '${widget.memberCount}');

  @override
  void dispose() {
    _count.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final next = (widget.memberCount + delta).clamp(1, 99999);
    _count.text = '$next';
    widget.onMemberCountChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('방 종류'),
        Row(
          children: [
            for (final t in _types)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: t == _types.last ? 0 : 8),
                  child: ChoiceChip(
                    selected: t == widget.type,
                    onSelected: (_) => widget.onTypeChanged(t),
                    showCheckmark: false,
                    avatar: Icon(RoomAvatar.iconFor(t), size: 18),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(t.label, textAlign: TextAlign.center),
                    ),
                    labelStyle: text.body.copyWith(fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
                    ),
                    side: BorderSide.none,
                    backgroundColor: palette.fill,
                    selectedColor: palette.accentSoft,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const FieldLabel('멤버 인원수'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: palette.fill,
            borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _step(-1),
                tooltip: '인원 줄이기',
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: TextField(
                  controller: _count,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(5),
                  ],
                  style: text.title,
                  decoration: const InputDecoration(filled: false, suffixText: '명'),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) widget.onMemberCountChanged(n);
                  },
                ),
              ),
              IconButton(
                onPressed: () => _step(1),
                tooltip: '인원 늘리기',
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
