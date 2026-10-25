import 'package:flutter/material.dart';

class LmsAvatar extends StatelessWidget {
  final String username;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final double radius;
  final Color? backgroundColor;

  const LmsAvatar({
    super.key,
    required this.username,
    required this.fullName,
    this.firstName,
    this.lastName,
    this.radius = 28,
    this.backgroundColor,
  });

  // Fonction pour obtenir les initiales style Google Meet (Prénom + Nom)
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';

    const commonSgLastnames = {
      'diop', 'ndiaye', 'sall', 'faye', 'gueye', 'diallo', 'ba', 'kane', 'sy', 
      'cisse', 'diagne', 'sow', 'fall', 'toure', 'keita', 'diouf', 'seck', 
      'thiam', 'mbacke', 'niang', 'balde', 'beye', 'ciss', 'coly', 'dabo', 
      'dia', 'diaw', 'dione', 'drame', 'gassama', 'mane', 'mbaye', 'ndaw', 
      'ndong', 'ndour', 'sene', 'sidibe', 'tall', 'wade', 'wane'
    };

    if (parts.length >= 2) {
      String? lastname;
      String? firstname;

      // 1. Détection par nom de famille entièrement en MAJUSCULES (ex: DIOP Medoune ou Medoune DIOP)
      for (final p in parts) {
        final isAllCaps = p.length > 1 && p == p.toUpperCase() && RegExp(r'^[A-ZÀ-Ÿ]+$').hasMatch(p);
        if (isAllCaps) {
          lastname = p;
        } else {
          firstname ??= p;
        }
      }

      // 2. Détection par liste de noms de famille sénégalais courants si écrit sous forme \"Nom Prénom\"
      if (lastname == null || firstname == null) {
        final firstLower = parts[0].toLowerCase();
        if (commonSgLastnames.contains(firstLower)) {
          lastname = parts[0];
          firstname = parts[parts.length - 1];
        }
      }

      if (lastname != null && firstname != null) {
        return '${firstname[0]}${lastname[0]}'.toUpperCase();
      }

      // Si tous les mots sont en majuscules (ex: DIOP MEDOUNE), l'usage académique écrit NOM Prénom.
      // Donc parts[0] = Nom, parts[parts.length-1] = Prénom. On veut Prénom + Nom.
      final isAllAllUpper = parts.every((p) => p == p.toUpperCase());
      if (isAllAllUpper) {
        final firstCharNom = parts[0][0];
        final firstCharPrenom = parts[parts.length - 1][0];
        return '$firstCharPrenom$firstCharNom'.toUpperCase();
      }

      // Format standard Prénom Nom (ex: Medoune Diop)
      final first = parts[0];
      final last = parts[parts.length - 1];
      return '${first[0]}${last[0]}'.toUpperCase();
    }

    final single = parts[0];
    final singleLower = single.toLowerCase();

    const commonSgFirstnames = {
      'medoune', 'moustapha', 'aziz', 'abdoul', 'fatou', 'bamba', 'khady', 
      'ousmane', 'cheikh', 'ibrahima', 'mariama', 'aminata', 'moussa', 
      'aliou', 'amadou', 'djibril', 'daba', 'mbacke', 'yacine', 'ngone',
      'aida', 'ramatoulaye', 'sokhna', 'serigne', 'fallou', 'modou', 'baye',
      'seyni', 'demba', 'birame', 'mor', 'ibra', 'alassane', 'ousseynou', 'assane'
    };

    // 1. Détecter si l'identifiant unique est [nom][prénom] (ex: diopmedoune)
    for (final ln in commonSgLastnames) {
      if (singleLower.startsWith(ln) && singleLower.length > ln.length) {
        final firstCharNom = ln[0].toUpperCase();
        final firstCharPrenom = singleLower[ln.length].toUpperCase();
        return '$firstCharPrenom$firstCharNom';
      }
    }

    // 2. Détecter si l'identifiant unique est [initiale nom][prénom] (ex: dmedoune pour Diop Medoune)
    if (singleLower.length > 2) {
      final firstLetter = singleLower[0];
      final remaining = singleLower.substring(1);
      if (commonSgFirstnames.contains(remaining)) {
        final firstCharNom = firstLetter.toUpperCase();
        final firstCharPrenom = remaining[0].toUpperCase();
        return '$firstCharPrenom$firstCharNom';
      }
    }

    // 3. Détecter si l'identifiant unique finit par un nom de famille connu (ex: msow pour Moustapha Sow)
    for (final ln in commonSgLastnames) {
      if (singleLower.endsWith(ln) && singleLower.length > ln.length) {
        final firstCharNom = ln[0].toUpperCase();
        final firstCharPrenom = singleLower[0].toUpperCase();
        return '$firstCharPrenom$firstCharNom';
      }
    }

    if (single.length >= 2) {
      return single.substring(0, 2).toUpperCase();
    }
    return single[0].toUpperCase();
  }

  // Palette de couleurs Google Meet déterministes basées sur le nom/username
  Color _getInitialsColor(String name) {
    final colors = [
      const Color(0xFF1E88E5), // Blue
      const Color(0xFF43A047), // Green
      const Color(0xFFE53935), // Red
      const Color(0xFFFB8C00), // Orange
      const Color(0xFF8E24AA), // Purple
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFF3949AB), // Indigo
      const Color(0xFF00897B), // Teal
    ];
    if (name.isEmpty) return colors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    String? resolvedFirstName = firstName;
    String? resolvedLastName = lastName;

    if ((resolvedFirstName == null || resolvedFirstName.trim().isEmpty) && 
        (resolvedLastName == null || resolvedLastName.trim().isEmpty) && 
        fullName.isNotEmpty) {
      final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        resolvedLastName = parts[parts.length - 1];
        resolvedFirstName = parts.sublist(0, parts.length - 1).join(' ');
      }
    }

    final hasFirstLast = resolvedFirstName != null && resolvedFirstName.trim().isNotEmpty && resolvedLastName != null && resolvedLastName.trim().isNotEmpty;
    final displayName = fullName.isNotEmpty ? fullName : username;
    final initials = hasFirstLast
        ? '${resolvedFirstName.trim()[0]}${resolvedLastName.trim()[0]}'.toUpperCase()
        : _getInitials(displayName);
    
    debugPrint('LMS_AVATAR_DEBUG: username="$username", fullName="$fullName", firstName="$resolvedFirstName", lastName="$resolvedLastName" => initials="$initials"');
    
    final bgColor = backgroundColor ?? _getInitialsColor(displayName);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: bgColor == Colors.white ? Colors.black87 : Colors.white,
            fontSize: radius * 0.75,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
