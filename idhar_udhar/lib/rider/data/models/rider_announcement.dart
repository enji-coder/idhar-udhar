enum RiderAnnouncementKind {
  incentive,
  referral,
  bonus,
  weekend,
  opportunity,
  update,
  policy,
}

class RiderAnnouncement {
  const RiderAnnouncement({
    required this.kind,
    required this.title,
    required this.body,
    this.badge,
    this.dateLabel,
  });

  final RiderAnnouncementKind kind;
  final String title;
  final String body;
  final String? badge;
  final String? dateLabel;
}
