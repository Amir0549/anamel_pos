class UserModel {
  final int? id;
  final String name;
  final String password;
  final String role; // 'admin' or 'seller'

  const UserModel({
    this.id,
    required this.name,
    required this.password,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isSeller => role == 'seller';

  String get roleTitle => isAdmin ? 'مدير' : 'بائع';
  String get roleFullTitle => isAdmin ? 'مدير النظام (Admin)' : 'بائع (Seller)';

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name.trim(),
      'password': password,
      'role': role,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      password: (map['password'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'seller',
    );
  }

  UserModel copyWith({
    int? id,
    String? name,
    String? password,
    String? role,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          role == other.role;

  @override
  int get hashCode => id.hashCode ^ name.hashCode ^ role.hashCode;
}
