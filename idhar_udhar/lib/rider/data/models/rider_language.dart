const List<RiderLanguageOption> riderLanguageOptions = <RiderLanguageOption>[
  RiderLanguageOption(code: 'en', label: 'English'),
  RiderLanguageOption(code: 'hi', label: 'Hindi'),
  RiderLanguageOption(code: 'gu', label: 'Gujarati'),
];

class RiderLanguageOption {
  const RiderLanguageOption({required this.code, required this.label});

  final String code;
  final String label;
}

String riderLanguageLabel(String? codeOrLabel) {
  final String value = (codeOrLabel ?? '').trim();
  if (value.isEmpty) return '';
  for (final RiderLanguageOption option in riderLanguageOptions) {
    if (option.code == value || option.label == value) return option.label;
  }
  return value;
}

String? riderLanguageCode(String? codeOrLabel) {
  final String value = (codeOrLabel ?? '').trim();
  if (value.isEmpty) return null;
  for (final RiderLanguageOption option in riderLanguageOptions) {
    if (option.code == value || option.label == value) return option.code;
  }
  return null;
}
