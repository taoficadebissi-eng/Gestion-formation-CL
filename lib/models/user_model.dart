enum UserRole { admin, formateur, apprenant }

class UserModel {
  final String id;
  final String nom;
  final String prenom;
  final String email;
  final UserRole role;
  final String centreId;
  final bool isFirstLogin;

  UserModel({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    required this.role,
    required this.centreId,
    this.isFirstLogin = false,
  });

  // Getter semantique : vrai si l'utilisateur doit changer son mot de passe
  bool get mustChangePassword => isFirstLogin;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: json['id'] ?? '',
    nom: json['nom'] ?? '',
    prenom: json['prenom'] ?? '',
    email: json['email'] ?? '',
    role: UserRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => UserRole.apprenant,
    ),
    // centre_id est nullable côté Postgres (l'admin n'a pas de centre sur
    // son propre profil) — on garde '' côté Dart pour ne rien changer au
    // reste de l'app, qui teste déjà `centreId.isEmpty`.
    centreId: json['centre_id'] ?? '',
    isFirstLogin: json['is_first_login'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'email': email,
    'role': role.name,
    'centre_id': centreId.isEmpty ? null : centreId,
    'is_first_login': isFirstLogin,
  };
}
