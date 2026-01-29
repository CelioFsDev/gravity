from pathlib import Path
path = Path('lib/features/admin/settings/settings_screen.dart')
text = path.read_text()
marker = "class _StoreSettingsForm extends ConsumerStatefulWidget"
idx = text.index(marker)
dup_start = text.index("\n  Future<void> _runMigration", idx)
dup_end = text.index("class _StoreSettingsFormState extends", dup_start)
text = text[:dup_start] + "\n" + text[dup_end:]
path.write_text(text)
