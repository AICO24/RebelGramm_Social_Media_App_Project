class UserModel {
  final String id;
  final String email;
  final String username;
  final String profilePic;

  UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.profilePic,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'profilePic': profilePic,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      profilePic: map['profilePic'] ?? '',
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? profilePic,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      profilePic: profilePic ?? this.profilePic,
    );
  }
}
