double? parseNumberWithUnits(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(0)!);
}

int? parseWholeNumberWithUnits(String value) {
  return parseNumberWithUnits(value)?.round();
}
