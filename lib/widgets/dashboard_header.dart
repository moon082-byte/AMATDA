import 'package:flutter/material.dart';

import '../services/inbox_service.dart';
import '../services/profile_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/maybe_provider.dart';
import 'profile_avatar.dart';

/// 메인 화면 맨 위 줄: 좌상단 프로필(사진+닉네임, 누르면 프로필), 우상단 🔔 알림함(안 읽은 개수)·설정
class DashboardHeader extends StatelessWidget {
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenSettings;

  const DashboardHeader({
    super.key,
    required this.onOpenProfile,
    required this.onOpenInbox,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final profile = maybeProvider<ProfileService>(context);
    final inbox = maybeProvider<InboxService>(context);
    final iconStyle = IconButton.styleFrom(backgroundColor: palette.card);

    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: profile == null || !profile.available
                ? const SizedBox.shrink()
                : Semantics(
                    button: true,
                    label: '내 프로필',
                    child: InkWell(
                      onTap: onOpenProfile,
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(2, 2, 10, 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProfileAvatar(profile: profile.profile, size: 36),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                profile.profile.nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.title,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        if (inbox != null && inbox.available)
          IconButton(
            onPressed: onOpenInbox,
            tooltip: '알림함',
            style: iconStyle,
            icon: Badge(
              isLabelVisible: inbox.unread > 0,
              label: Text(inbox.unread > 99 ? '99+' : '${inbox.unread}'),
              child: Icon(Icons.notifications_rounded, color: palette.subText),
            ),
          ),
        const SizedBox(width: 6),
        IconButton(
          onPressed: onOpenSettings,
          tooltip: '설정',
          style: iconStyle,
          icon: Icon(Icons.settings_rounded, color: palette.subText),
        ),
      ],
    );
  }
}
