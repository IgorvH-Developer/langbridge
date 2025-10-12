
import 'package:LangBridge/config/app_config.dart';

class UserLanguage {
  final int id;
  final String name;
  final String code;
  final String level;
  final String type; // 'native' or 'learning'

  UserLanguage({
    required this.id,
    required this.name,
    required this.code,
    required this.level,
    required this.type,
  });

  factory UserLanguage.fromJson(Map<String, dynamic> json) {
    return UserLanguage(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      level: json['level'],
      type: json['type'],
    );
  }
}

class UserProfile {
  final String id;
  final String username;
  final String? fullName;
  final String? gender;
  final int? age;
  final String? country;
  final int? height;
  final String? bio;
  final String? avatarUrl;
  final String? interests;
  final List<UserLanguage> languages;

  UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.gender,
    this.age,
    this.country,
    this.height,
    this.bio,
    this.avatarUrl,
    this.interests,
    required this.languages,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    var langList = (json['languages'] as List<dynamic>?) ?? [];
    List<UserLanguage> parsedLanguages =
    langList.map((i) => UserLanguage.fromJson(i)).toList();

    String? rawAvatarUrl = json['avatar_url'];
    String? fullAvatarUrl;
    if (rawAvatarUrl != null && rawAvatarUrl.isNotEmpty) {
      if (rawAvatarUrl.startsWith('http')) {
        fullAvatarUrl = rawAvatarUrl;
      } else {
        fullAvatarUrl = "${AppConfig.apiBaseUrl}$rawAvatarUrl";
      }
    }

    return UserProfile(
      id: json['id'],
      username: json['username'],
      fullName: json['full_name'],
      gender: json['gender'],
      age: json['age'],
      country: json['country'],
      height: json['height'],
      bio: json['bio'],
      avatarUrl: fullAvatarUrl,
      interests: json['interests'],
      languages: parsedLanguages,
    );
  }
}
