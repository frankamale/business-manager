class Store {
  final String id;
  final String name;

  const Store({required this.id, required this.name});

  static const Store all = Store(id: '---all-stores-id---', name: 'All Stores');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}