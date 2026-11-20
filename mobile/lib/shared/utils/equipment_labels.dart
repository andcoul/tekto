// Localized names for the equipment vocabulary (FR-001, FR-033).
import 'package:tekto/core/l10n/gen/app_localizations.dart';

/// Localized label for an equipment key; unknown keys fall back to the key with spaces.
String equipmentLabel(AppLocalizations l10n, String key) => switch (key) {
      'barbell' => l10n.quizEquipmentBarbell,
      'dumbbell' => l10n.quizEquipmentDumbbell,
      'cable' => l10n.quizEquipmentCable,
      'machine' => l10n.quizEquipmentMachine,
      'bands' => l10n.quizEquipmentBands,
      'pull_up_bar' => l10n.quizEquipmentPullUpBar,
      'dip_station' => l10n.quizEquipmentDipStation,
      'bench' => l10n.quizEquipmentBench,
      'bodyweight' => l10n.quizEquipmentBodyweight,
      _ => key.replaceAll('_', ' '),
    };
