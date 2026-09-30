// Messages de jeu conviviaux FR/EN/AR pour les conditions attendues.
// L'UI n'affiche que ceci ; le détail brut reste dans l'exception (debug).
// L'appelant transmet Localizations.localeOf(context).languageCode.
//
// Correspondance EXACTE sur code discret (jamais de sous-chaîne) :
// 'pack-premium-locked' ne doit jamais tomber sur le message de 'locked'.
// On extrait les tokens à tirets du texte brut et on ne retient que les
// codes connus, du plus spécifique au plus générique.
String friendlyGameError(Object error, [String languageCode = 'fr']) {
  final code = _extractGameErrorCode('$error');
  return _localizedGameError(code, languageCode);
}

/// Extrait le code d'erreur serveur/client connu, ou null.
String? _extractGameErrorCode(String text) {
  const known = {
    'pseudo-invalide',
    'pack-manquant',
    'not-authenticated',
    'invalid-nickname',
    'invalid-language',
    'pack-not-found',
    'pack-hidden',
    'pack-not-visible',
    'pack-premium-locked',
    'pack-too-small',
    'pack-language-unavailable',
    'game-not-found',
    'game-already-started',
    'nickname-taken',
    'game-full',
    'team-not-found',
    'not-enough-players',
    'not-member',
    'not-host',
    'not-open',
    'not-locked',
    'not-allowed-yet',
    'locked',
    'empty-answer',
    'invalid-final-wager',
    'invalid-wager',
    'wager-already-used',
    'wrong-index',
    'bad-transition',
    'session-absente',
  };
  for (final m in RegExp(r'[a-z]+(?:-[a-z0-9]+)*').allMatches(text)) {
    final token = m.group(0)!;
    if (known.contains(token)) return token;
  }
  return null;
}

String _localizedGameError(String? code, String languageCode) {
  final en = languageCode == 'en';
  final ar = languageCode == 'ar';
  String t(String f, String e, String a) => en ? e : ar ? a : f;
  switch (code) {
    case 'pseudo-invalide':
    case 'invalid-nickname':
      return t('Pseudo invalide.', 'Invalid nickname.',
          'الاسم المستعار غير صالح.');
    case 'pack-manquant':
      return t('Aucun pack sélectionné.', 'No pack selected.',
          'لم يتم اختيار أي حزمة.');
    case 'not-authenticated':
      return t(
          'Session perdue : reconnecte-toi.',
          'Session lost: please sign in again.',
          'فُقدت الجلسة: سجل الدخول مجددًا.');
    case 'invalid-language':
      return t('Langue de partie invalide.', 'Invalid game language.',
          'لغة اللعبة غير صالحة.');
    case 'pack-not-found':
      return t('Pack introuvable.', 'Pack not found.',
          'الحزمة غير موجودة.');
    case 'pack-hidden':
      return t('Ce pack n’est plus disponible.',
          'This pack is no longer available.', 'هذه الحزمة لم تعد متاحة.');
    case 'pack-not-visible':
      return t(
          'Tu n’as pas accès à ce pack.',
          'You do not have access to this pack.',
          'ليس لديك صلاحية الوصول إلى هذه الحزمة.');
    case 'pack-premium-locked':
      return t(
          'Ce pack premium n’est pas débloqué.',
          'This premium pack is not unlocked.',
          'لم يتم فتح هذه الحزمة المميزة.');
    case 'pack-too-small':
      return t('Pack incomplet : 11 questions minimum.',
          'Incomplete pack: at least 11 questions.',
          'الحزمة غير مكتملة: 11 سؤالًا على الأقل.');
    case 'pack-language-unavailable':
      return t(
          'Ce pack n’est pas disponible en arabe.',
          'This pack is not available in Arabic.',
          'هذه الحزمة غير متاحة باللغة العربية.');
    case 'game-not-found':
      return t('Partie introuvable. Vérifie le code.',
          'Game not found. Check the code.', 'اللعبة غير موجودة. تحقق من الرمز.');
    case 'game-already-started':
      return t('La partie a déjà commencé.', 'The game already started.',
          'اللعبة بدأت بالفعل.');
    case 'nickname-taken':
      return t(
          'Ce pseudo est déjà pris dans cette partie.',
          'This nickname is already taken in this game.',
          'هذا الاسم المستعار مستخدم بالفعل في هذه اللعبة.');
    case 'game-full':
      return t(
          'Partie complète (50 joueurs max).',
          'Game is full (50 players max).',
          'اللعبة ممتلئة (50 لاعبًا كحد أقصى).');
    case 'team-not-found':
      return t('Équipe introuvable.', 'Team not found.',
          'الفريق غير موجود.');
    case 'not-enough-players':
      return t(
          'Il faut au moins 2 joueurs pour démarrer.',
          'At least 2 players are needed to start.',
          'يلزم لاعبان على الأقل للبدء.');
    case 'not-member':
      return t('Tu n’es pas membre de cette partie.',
          'You are not a member of this game.', 'لست عضوًا في هذه اللعبة.');
    case 'not-host':
      return t('Seul l’hôte peut faire ça.', 'Only the host can do that.',
          'المضيف فقط يمكنه فعل ذلك.');
    case 'not-open':
      return t(
          'Question fermée : attends la suivante.',
          'Question closed: wait for the next one.',
          'السؤال مغلق: انتظر التالي.');
    case 'not-locked':
      return t(
          'La question n’est pas encore verrouillée.',
          'The question is not locked yet.',
          'السؤال غير مقفل بعد.');
    case 'not-allowed-yet':
      return t(
          'Verrouillage trop tôt : attends la fin du timer.',
          'Too early to lock: wait for the timer.',
          'القفل مبكر جدًا: انتظر نهاية المؤقت.');
    case 'locked':
      return t('Temps écoulé : question verrouillée.',
          'Time is up: question locked.', 'انتهى الوقت: السؤال مقفل.');
    case 'empty-answer':
      return t('Écris une réponse avant de valider.',
          'Write an answer before submitting.', 'اكتب إجابة قبل التأكيد.');
    case 'invalid-final-wager':
      return t(
          'Mise finale : 0, 10 ou 20 uniquement.',
          'Final wager: 0, 10 or 20 only.',
          'الرهان الأخير: 0 أو 10 أو 20 فقط.');
    case 'invalid-wager':
      return t('Mise invalide pour cette question.',
          'Invalid wager for this question.', 'رهان غير صالح لهذا السؤال.');
    case 'wager-already-used':
      return t(
          'Mise déjà utilisée : choisis-en une autre.',
          'Wager already used: pick another one.',
          'الرهان مستخدم بالفعل: اختر رهانًا آخر.');
    case 'wrong-index':
      return t('Question périmée : recharge l’état.',
          'Stale question: reload the state.', 'سؤال قديم: أعد تحميل الحالة.');
    case 'bad-transition':
      return t(
          'Action impossible dans l’état actuel.',
          'Action not allowed in the current state.',
          'الإجراء غير ممكن في الحالة الحالية.');
    case 'session-absente':
      return t(
          'Session perdue : rejoins la partie à nouveau.',
          'Session lost: join the game again.',
          'فُقدت الجلسة: انضم إلى اللعبة مجددًا.');
    default:
      return t(
          'Erreur réseau ou serveur. Réessaie.',
          'Network or server error. Try again.',
          'خطأ في الشبكة أو الخادم. حاول مجددًا.');
  }
}

/// Messages UGC FR/EN/AR : validation cliente (mêmes codes que le serveur)
/// + erreurs RPC. Jamais de texte PostgREST brut en UI.
/// Les codes indexés (`invalid-question:3`) sont réduits à leur base.
String friendlyUgcError(Object error, String languageCode) {
  final en = languageCode == 'en';
  final ar = languageCode == 'ar';
  String t(String f, String e, String a) => en ? e : ar ? a : f;
  // Codes serveur type `invalid-question` (éventuellement `invalid-question:3`
  // côté validation cliente) : premier token à tirets du texte brut.
  final code =
      RegExp(r'[a-z]+(?:-[a-z]+)+').firstMatch('$error')?.group(0) ?? '';
  switch (code) {
    case 'terms-required':
      return t(
          'Tu dois accepter les CGU de création de contenu.',
          'You must accept the content terms to create a pack.',
          'يجب قبول شروط إنشاء المحتوى لإنشاء حزمة.');
    case 'invalid-title':
      return t(
          'Le titre doit faire 2 à 80 caractères (FR, EN, AR).',
          'Title must be 2–80 characters (FR, EN, AR).',
          'يجب أن يكون العنوان من 2 إلى 80 حرفًا (بالفرنسية والإنجليزية والعربية).');
    case 'invalid-description':
      return t(
          'La description doit faire 500 caractères max.',
          'Description must be 500 characters max.',
          'يجب ألا يتجاوز الوصف 500 حرف.');
    case 'invalid-questions':
      return t('Liste de questions invalide.', 'Invalid question list.',
          'قائمة الأسئلة غير صالحة.');
    case 'pack-too-small':
      return t(
          'Un pack nécessite au moins 11 questions.',
          'A pack needs at least 11 questions.',
          'تتطلب الحزمة 11 سؤالًا على الأقل.');
    case 'pack-too-large':
      return t('Un pack contient 100 questions max.',
          'A pack holds 100 questions max.', 'تحتوي الحزمة على 100 سؤال كحد أقصى.');
    case 'invalid-question':
      return t(
          'Chaque question doit faire 2 à 500 caractères (FR, EN, AR).',
          'Each question must be 2–500 characters (FR, EN, AR).',
          'يجب أن يكون كل سؤال من 2 إلى 500 حرف (بالفرنسية والإنجليزية والعربية).');
    case 'invalid-answer':
      return t(
          'Chaque réponse doit faire 1 à 200 caractères (FR, EN, AR).',
          'Each answer must be 1–200 characters (FR, EN, AR).',
          'يجب أن تكون كل إجابة من 1 إلى 200 حرف (بالفرنسية والإنجليزية والعربية).');
    case 'invalid-category':
      return t(
          'La catégorie doit faire 1 à 40 caractères.',
          'Category must be 1–40 characters.',
          'يجب أن تكون الفئة من 1 إلى 40 حرفًا.');
    case 'invalid-difficulty':
      return t('La difficulté doit être 1, 2 ou 3.',
          'Difficulty must be 1, 2 or 3.', 'يجب أن تكون الصعوبة 1 أو 2 أو 3.');
    case 'invalid-match-mode':
      return t('Le mode doit être exact ou fuzzy.',
          'Match mode must be exact or fuzzy.', 'يجب أن يكون الوضع مطابقًا تامًا أو مرنًا.');
    case 'invalid-aliases':
      return t(
          'Les alias doivent être du texte, 100 caractères max chacun.',
          'Aliases must be text, 100 characters max each.',
          'يجب أن تكون المرادفات نصًا، بحد أقصى 100 حرف لكل منها.');
    case 'too-many-aliases':
      return t('20 alias max par langue.', '20 aliases max per language.',
          '20 مرادفًا كحد أقصى لكل لغة.');
    case 'ugc-image-forbidden':
      return t(
          'Les images sont interdites dans les packs communautaires.',
          'Images are not allowed in community packs.',
          'الصور ممنوعة في الحزم المجتمعية.');
    case 'pack-not-found':
      return t('Pack introuvable.', 'Pack not found.', 'الحزمة غير موجودة.');
    case 'pack-not-editable':
      return t(
          'Seul le propriétaire peut modifier ce pack.',
          'Only the owner can edit this pack.',
          'فقط المالك يمكنه تعديل هذه الحزمة.');
    case 'pack-in-use':
      return t(
          'Ce pack est utilisé par une partie existante et ne peut pas encore être modifié.',
          'This pack is used by an existing game and cannot be edited yet.',
          'هذه الحزمة مستخدمة في لعبة حالية ولا يمكن تعديلها بعد.');
    case 'arabic-content-required':
      return t(
          'Ce pack contient déjà de l’arabe : les champs arabes sont requis.',
          'This pack already has Arabic content: Arabic fields are required.',
          'تحتوي هذه الحزمة على محتوى عربي: الحقول العربية مطلوبة.');
    case 'invalid-arabic-content':
      return t(
          'Le prompt et la réponse arabes doivent être fournis ensemble.',
          'Arabic prompt and answer must be provided together.',
          'يجب تقديم السؤال والإجابة بالعربية معًا.');
    case 'pack-language-unavailable':
      return t(
          'Ce pack n’est pas disponible en arabe.',
          'This pack is not available in Arabic.',
          'هذه الحزمة غير متاحة باللغة العربية.');
    default:
      return t('Erreur réseau ou serveur. Réessaie.',
          'Network or server error. Try again.', 'خطأ في الشبكة أو الخادم. حاول مجددًا.');
  }
}
