enum NotificationTopic {
  menu('cafeteria_menu', 'Menú de la cafetería'),
  offers('cafeteria_ofertas', 'Ofertas'),
  tips('cafeteria_consejos', 'Consejos de la cafetería'),
  announcements('cafeteria_avisos', 'Avisos de la cafetería');

  const NotificationTopic(this.key, this.label);

  final String key;
  final String label;

  static NotificationTopic? fromKey(String key) {
    for (final topic in values) {
      if (topic.key == key) return topic;
    }
    return null;
  }
}

class NotificationTopicPreferences {
  const NotificationTopicPreferences({
    this.menu = false,
    this.offers = false,
    this.tips = false,
    this.announcements = false,
    this.localAdvice = false,
  });

  static const localAdviceKey = 'consejos_cafeteria';

  final bool menu;
  final bool offers;
  final bool tips;
  final bool announcements;
  final bool localAdvice;

  bool isEnabled(NotificationTopic topic) => switch (topic) {
    NotificationTopic.menu => menu,
    NotificationTopic.offers => offers,
    NotificationTopic.tips => tips,
    NotificationTopic.announcements => announcements,
  };

  NotificationTopicPreferences withTopic(
    NotificationTopic topic,
    bool enabled,
  ) => switch (topic) {
    NotificationTopic.menu => copyWith(menu: enabled),
    NotificationTopic.offers => copyWith(offers: enabled),
    NotificationTopic.tips => copyWith(tips: enabled),
    NotificationTopic.announcements => copyWith(announcements: enabled),
  };

  NotificationTopicPreferences copyWith({
    bool? menu,
    bool? offers,
    bool? tips,
    bool? announcements,
    bool? localAdvice,
  }) => NotificationTopicPreferences(
    menu: menu ?? this.menu,
    offers: offers ?? this.offers,
    tips: tips ?? this.tips,
    announcements: announcements ?? this.announcements,
    localAdvice: localAdvice ?? this.localAdvice,
  );

  Map<String, bool> toMap() => {
    NotificationTopic.menu.key: menu,
    NotificationTopic.offers.key: offers,
    NotificationTopic.tips.key: tips,
    NotificationTopic.announcements.key: announcements,
    localAdviceKey: localAdvice,
  };

  factory NotificationTopicPreferences.fromMap(Object? value) {
    if (value is! Map) return const NotificationTopicPreferences();

    return NotificationTopicPreferences(
      menu: value[NotificationTopic.menu.key] == true,
      offers: value[NotificationTopic.offers.key] == true,
      tips: value[NotificationTopic.tips.key] == true,
      announcements: value[NotificationTopic.announcements.key] == true,
      localAdvice: value[localAdviceKey] == true,
    );
  }
}
