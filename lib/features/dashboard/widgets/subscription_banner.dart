import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Föreningens abonnemang (brf-samlat-pb GET /api/subscription,
/// pb_hooks/utils/subscription_utils.js). Samma lägen som bannern på webben
/// (brf-samlat-nuxt-app layouts/admin.vue).
///
/// Appen visar bara läget. Abonnemanget väljs, utökas och sägs upp på webben
/// under Administration → Abonnemang. Det finns medvetet ingen knapp eller länk
/// dit: App Store-reglerna (3.1.1) begränsar länkar till köp utanför appen.
class SubscriptionStatus {
  /// "trial" | "active" | "expired" | "cancelled"
  final String state;
  final bool cancelled;
  final DateTime? accessUntil;
  final int trialDaysLeft;
  final int quotaBytes;
  final int usedBytes;
  final bool canManage;

  const SubscriptionStatus({
    required this.state,
    required this.cancelled,
    required this.accessUntil,
    required this.trialDaysLeft,
    required this.quotaBytes,
    required this.usedBytes,
    required this.canManage,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    int toInt(Object? v) => v is num ? v.toInt() : 0;
    final until = json['access_until'] as String? ?? '';
    return SubscriptionStatus(
      state: json['state'] as String? ?? 'active',
      cancelled: json['cancelled'] == true,
      accessUntil: until.isEmpty ? null : DateTime.tryParse(until)?.toLocal(),
      trialDaysLeft: toInt(json['trial_days_left']),
      quotaBytes: toInt(json['quota_bytes']),
      usedBytes: toInt(json['used_bytes']),
      canManage: json['can_manage'] == true,
    );
  }

  bool get isReadOnly => state == 'expired' || state == 'cancelled';
}

/// "0,8 GB".
String formatStorage(int bytes) {
  final gb = (bytes / (1024 * 1024 * 1024) * 10).round() / 10;
  final text = gb == gb.roundToDouble() ? gb.toInt().toString() : gb.toString();
  return '${text.replaceAll('.', ',')} GB';
}

const _months = [
  'januari', 'februari', 'mars', 'april', 'maj', 'juni', 'juli', 'augusti',
  'september', 'oktober', 'november', 'december',
];

String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// Texten i bannern, eller null när inget behöver visas.
({String title, String body, bool attention})? subscriptionBannerText(
  SubscriptionStatus s,
) {
  const where = 'Välj abonnemang på webben under Administration → Abonnemang.';
  if (s.state == 'expired' || s.state == 'cancelled') {
    final what = s.state == 'expired'
        ? 'Gratismånaden är slut'
        : 'Abonnemanget är avslutat';
    return (
      title: s.canManage ? what : 'Föreningen: ${what.toLowerCase()}',
      body: s.canManage
          ? 'Allt går att läsa, men inget nytt kan sparas. $where'
          : 'Allt går att läsa, men inget nytt kan sparas förrän föreningens administratör har valt abonnemang.',
      attention: true,
    );
  }
  if (!s.canManage) return null;
  if (s.state == 'active' && s.cancelled && s.accessUntil != null) {
    return (
      title: 'Abonnemanget är uppsagt',
      body:
          'Det gäller till ${_date(s.accessUntil!)}, sedan blir BRF Samlat skrivskyddat. $where',
      attention: false,
    );
  }
  if (s.state == 'trial') {
    final days = s.trialDaysLeft;
    return (
      title: 'Gratismånad – ${days == 1 ? '1 dag' : '$days dagar'} kvar',
      body: where,
      attention: days <= 7,
    );
  }
  if (s.quotaBytes > 0 && s.usedBytes / s.quotaBytes >= 0.9) {
    return (
      title: 'Lagringen är nästan full',
      body:
          '${formatStorage(s.usedBytes)} av ${formatStorage(s.quotaBytes)} används. Utöka lagringen på webben under Administration → Abonnemang.',
      attention: true,
    );
  }
  return null;
}

class SubscriptionBanner extends StatelessWidget {
  final SubscriptionStatus status;

  const SubscriptionBanner({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final text = subscriptionBannerText(status);
    if (text == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fg = text.attention ? AppTheme.attentionOf(context) : colors.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: text.attention
            ? AppTheme.attentionFillOf(context)
            : colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusTile),
        border: text.attention ? null : Border.all(color: colors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            status.isReadOnly
                ? Icons.lock_outline_rounded
                : Icons.event_outlined,
            color: fg,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.title,
                  style: textTheme.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  text.body,
                  style: textTheme.bodyMedium?.copyWith(
                    color: text.attention ? fg : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
