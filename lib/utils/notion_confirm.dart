import 'package:flutter/material.dart';
import '../models/notion_settings.dart';
import 'confirm_action.dart';

/// [기존 항목 보내기] 확인
Future<bool> confirmNotionBackfill(BuildContext context, NotionTarget t) => confirmAction(context,
    title: '기존 ${t.label}을(를) 노션에 보낼까요?',
    message: '아직 노션에 없는 ${t.label}을(를) 모두 만들어요. 많으면 몇 분 걸려요.',
    confirmLabel: '보내기');

/// [연동 해제] 확인
Future<bool> confirmNotionDisconnect(BuildContext context) => confirmAction(context,
    title: '노션 연동을 해제할까요?',
    message: '저장된 토큰과 데이터베이스 설정을 지워요. 이미 만든 노션 페이지는 그대로 남아요.',
    confirmLabel: '해제');
