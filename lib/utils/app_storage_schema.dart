class AppStorageSchema {
  const AppStorageSchema._();

  static const coursesKey = 'courses';
  static const displayDaysKey = 'display_days';
  static const showNonCurrentWeekKey = 'show_non_current_week';

  static const lastFetchTimeKey = 'last_fetch_time';
  static const lastAttemptTimeKey = 'last_auto_sync_attempt_time';
  static const lastErrorKey = 'last_auto_sync_error';
  static const lastMessageKey = 'last_auto_sync_message';
  static const lastStateKey = 'last_auto_sync_state';
  static const lastSourceKey = 'last_auto_sync_source';
  static const lastDiffSummaryKey = 'last_auto_sync_diff_summary';
  static const lastStateSemesterCodeKey = 'last_auto_sync_state_semester_code';
  static const nextSyncTimeKey = 'next_background_sync_time';
  static const frequencyKey = 'auto_sync_frequency';
  static const customIntervalMinutesKey = 'auto_sync_custom_interval_minutes';

  static const semesterKey = 'last_semester_code';
  static const legacySemesterKey = 'current_semester';
  static const activeSemesterKey = 'active_semester_code';
  static const scheduleArchiveKey = 'schedule_archive_by_semester';
  static const semesterCatalogKey = 'known_semester_catalog';
  static const semesterSyncRecordsKey = 'semester_sync_records';
  static const hasSyncedAtLeastOneSemesterKey =
      'has_synced_at_least_one_semester';
  static const scheduleOverridesKey = 'schedule_overrides';
  static const schoolTimeConfigKey = 'school_time_config';
  static const schoolTimeGeneratorSettingsKey =
      'school_time_generator_settings';
  static const lastScheduleJsonKey = 'last_schedule_json';

  static const cookieSnapshotKey = 'last_auto_sync_cookie';
  static const cookieSnapshotInvalidatedKey =
      'last_auto_sync_cookie_invalidated';
  static const syncInvalidationFlagKey = 'sync_invalidation_flag';
  static const syncWritingLockKey = 'sync_writing_lock';
  static const studentIdKey = 'last_student_id';

  static const reminderLeadTimeKey = 'class_reminder_lead_minutes';
  static const reminderLastBuildTimeKey = 'class_reminder_last_build_time';
  static const reminderHorizonEndKey = 'class_reminder_horizon_end';
  static const reminderScheduledCountKey = 'class_reminder_scheduled_count';
  static const reminderExactAlarmEnabledKey =
      'class_reminder_exact_alarm_enabled';

  static const classSilenceEnabledKey = 'class_silence_enabled';
  static const classSilenceLastBuildTimeKey = 'class_silence_last_build_time';
  static const classSilenceHorizonEndKey = 'class_silence_horizon_end';
  static const classSilenceScheduledCountKey = 'class_silence_scheduled_count';

  static const themeIdKey = 'theme_id';
  static const customBgPathKey = 'custom_bg_path';
  static const bgOpacityKey = 'bg_opacity';
  static const bgBlurKey = 'bg_blur';
  static const cardOpacityKey = 'card_opacity';
  static const followSystemThemeKey = 'follow_system_theme';
  static const systemLightThemeIdKey = 'system_light_theme_id';
  static const systemDarkThemeIdKey = 'system_dark_theme_id';

  static const miniOpacityKey = 'mini_opacity';
  static const miniAlwaysOnTopKey = 'mini_always_on_top';

  static const backupKeys = <String>[
    displayDaysKey,
    showNonCurrentWeekKey,
    frequencyKey,
    customIntervalMinutesKey,
    semesterKey,
    legacySemesterKey,
    activeSemesterKey,
    scheduleArchiveKey,
    semesterCatalogKey,
    semesterSyncRecordsKey,
    hasSyncedAtLeastOneSemesterKey,
    scheduleOverridesKey,
    schoolTimeConfigKey,
    schoolTimeGeneratorSettingsKey,
    reminderLeadTimeKey,
    classSilenceEnabledKey,
    themeIdKey,
    customBgPathKey,
    bgOpacityKey,
    bgBlurKey,
    cardOpacityKey,
    followSystemThemeKey,
    systemLightThemeIdKey,
    systemDarkThemeIdKey,
    miniOpacityKey,
    miniAlwaysOnTopKey,
  ];

  static const transientKeys = <String>[
    coursesKey,
    lastFetchTimeKey,
    lastAttemptTimeKey,
    lastErrorKey,
    lastMessageKey,
    lastStateKey,
    lastSourceKey,
    lastDiffSummaryKey,
    lastStateSemesterCodeKey,
    nextSyncTimeKey,
    lastScheduleJsonKey,
    cookieSnapshotKey,
    cookieSnapshotInvalidatedKey,
    syncInvalidationFlagKey,
    syncWritingLockKey,
    studentIdKey,
    reminderLastBuildTimeKey,
    reminderHorizonEndKey,
    reminderScheduledCountKey,
    reminderExactAlarmEnabledKey,
    classSilenceLastBuildTimeKey,
    classSilenceHorizonEndKey,
    classSilenceScheduledCountKey,
  ];

  static const semesterRelatedKeys = <String>[
    scheduleArchiveKey,
    semesterCatalogKey,
    activeSemesterKey,
  ];

  static const overrideRelatedKeys = <String>[scheduleOverridesKey];

  static const automationRelatedKeys = <String>[
    reminderLeadTimeKey,
    classSilenceEnabledKey,
  ];

  static const appearanceRelatedKeys = <String>[
    themeIdKey,
    customBgPathKey,
    bgOpacityKey,
    bgBlurKey,
    cardOpacityKey,
    followSystemThemeKey,
    systemLightThemeIdKey,
    systemDarkThemeIdKey,
    miniOpacityKey,
    miniAlwaysOnTopKey,
  ];
}
