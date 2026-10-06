import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import 'field_label.dart';

/// 새 할 일을 넣을 업무방 고르기 ('업무방 없음' 포함)
class RoomPicker extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const RoomPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final rooms = context.watch<RoomProvider>().rooms;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('업무방'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              selected: value == null,
              onSelected: (_) => onChanged(null),
              showCheckmark: false,
              label: const Text('업무방 없음'),
            ),
            for (final room in rooms)
              ChoiceChip(
                selected: value == room.id,
                onSelected: (_) => onChanged(room.id),
                showCheckmark: false,
                label: Text(room.name),
              ),
          ],
        ),
      ],
    );
  }
}
