class LocalizedItem {
  final String key;
  final List<String>? translations;
  final String? fieldName;

  LocalizedItem(this.key, this.translations, this.fieldName);
}

List<String>? keysOf(List<LocalizedItem>? items) {
  return items!.map((x) => x.key).toList();
}
