class Category {
  int? id;
  String? name;

  Category({
    this.id,
    this.name,
  });
  
  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['idCategory'] as int?,
      name: map['name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
    };
  }

  @override
  String toString() {
    return 'Category{id: $id, name: $name}';
  }
}