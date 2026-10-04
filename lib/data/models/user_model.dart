enum UserRole {
  petugas,
  supervisor,
  ho;

  String get displayName {
    switch (this) {
      case UserRole.petugas:
        return 'Petugas Lapangan';
      case UserRole.supervisor:
        return 'Supervisor / Koordinator';
      case UserRole.ho:
        return 'Head Office / Admin';
    }
  }

  static UserRole fromString(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'supervisor':
        return UserRole.supervisor;
      case 'ho':
      case 'headoffice':
        return UserRole.ho;
      case 'petugas':
      default:
        return UserRole.petugas;
    }
  }
}

class UserModel {
  final String id;
  final String nama;
  final String npp;
  final String email;
  final UserRole role;
  final String posId;
  final String posName;
  final String cabangName;

  UserModel({
    required this.id,
    required this.nama,
    required this.npp,
    required this.email,
    required this.role,
    required this.posId,
    required this.posName,
    required this.cabangName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'npp': npp,
    'email': email,
    'role': role.name,
    'posId': posId,
    'posName': posName,
    'cabangName': cabangName,
  };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] as String,
    nama: json['nama'] as String,
    npp: json['npp'] as String? ?? 'BSS-001',
    email: json['email'] as String,
    role: UserRole.fromString(json['role'] as String? ?? 'petugas'),
    posId: json['posId'] as String? ?? 'POS-01',
    posName: json['posName'] as String? ?? 'Pos Gate Utama',
    cabangName: json['cabangName'] as String? ?? 'BSS Manado Megamas',
  );

  UserModel copyWith({
    String? id,
    String? nama,
    String? npp,
    String? email,
    UserRole? role,
    String? posId,
    String? posName,
    String? cabangName,
  }) {
    return UserModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      npp: npp ?? this.npp,
      email: email ?? this.email,
      role: role ?? this.role,
      posId: posId ?? this.posId,
      posName: posName ?? this.posName,
      cabangName: cabangName ?? this.cabangName,
    );
  }
}
