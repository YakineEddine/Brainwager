// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Brainwager';

  @override
  String get tagline => 'راهن على ما تعرف';

  @override
  String get createGame => 'إنشاء لعبة';

  @override
  String get joinGame => 'الانضمام';

  @override
  String get packs => 'الحزم';

  @override
  String get shop => 'المتجر';

  @override
  String get settings => 'الإعدادات';

  @override
  String get joinCode => 'رمز اللعبة';

  @override
  String get nickname => 'الاسم المستعار';

  @override
  String get start => 'ابدأ';

  @override
  String get nextQuestion => 'السؤال التالي';

  @override
  String get lockAnswers => 'قفل الإجابات';

  @override
  String get revealAnswer => 'كشف الإجابة';

  @override
  String get finalWagerTitle => 'السؤال الأخير — الرهان 0 أو 10 أو 20';

  @override
  String get packOfficial => 'رسمي';

  @override
  String get packMine => 'حزمتي';

  @override
  String get packPremium => 'مميز';

  @override
  String get packLocked => 'مقفل';

  @override
  String get packComingSoon => 'قريبًا';

  @override
  String get packRetry => 'إعادة المحاولة';

  @override
  String get packLoadError => 'تعذر التحميل';

  @override
  String get packEmpty => 'لا توجد حزم متاحة';

  @override
  String get packChoosePack => 'اختر حزمة';

  @override
  String get packNoAccessiblePack => 'لا توجد حزمة متاحة لإنشاء لعبة';

  @override
  String get packPreview => 'معاينة';

  @override
  String get packCreate => 'إنشاء حزمة';

  @override
  String get packEdit => 'تعديل';

  @override
  String get editorSave => 'حفظ';

  @override
  String get editorSaved => 'تم الحفظ';

  @override
  String get editorTitleFr => 'العنوان بالفرنسية';

  @override
  String get editorTitleEn => 'العنوان بالإنجليزية';

  @override
  String get editorDescFr => 'الوصف بالفرنسية';

  @override
  String get editorDescEn => 'الوصف بالإنجليزية';

  @override
  String get editorQuestionFr => 'السؤال بالفرنسية';

  @override
  String get editorQuestionEn => 'السؤال بالإنجليزية';

  @override
  String get editorAnswerFr => 'الإجابة بالفرنسية';

  @override
  String get editorAnswerEn => 'الإجابة بالإنجليزية';

  @override
  String get editorAliasesFr => 'المرادفات بالفرنسية (واحد في كل سطر)';

  @override
  String get editorAliasesEn => 'المرادفات بالإنجليزية (واحد في كل سطر)';

  @override
  String get editorCategory => 'الفئة';

  @override
  String get editorDifficulty => 'الصعوبة';

  @override
  String get editorExact => 'مطابقة تامة';

  @override
  String get editorFuzzy => 'مطابقة مرنة';

  @override
  String get editorNumericExactNote => 'تُقيَّم الإجابات الرقمية بدقة تامة.';

  @override
  String get editorAddQuestion => 'إضافة سؤال';

  @override
  String get editorRemove => 'إزالة';

  @override
  String get editorMoveUp => 'تحريك لأعلى';

  @override
  String get editorMoveDown => 'تحريك لأسفل';

  @override
  String get editorTerms => 'أوافق على شروط إنشاء المحتوى';

  @override
  String get editorTermsAccepted => 'تم قبول الشروط';

  @override
  String get editorShareCode => 'رمز المشاركة';

  @override
  String get editorCopyCode => 'نسخ الرمز';

  @override
  String get editorCodeCopied => 'تم نسخ الرمز';

  @override
  String get editorFixErrors => 'صحح الحقول غير الصالحة';

  @override
  String get editorQuestions => 'الأسئلة';

  @override
  String get create => 'إنشاء';

  @override
  String get joinCodeHint => 'الرمز (4-6)';

  @override
  String get gameTitle => 'لعبة';

  @override
  String get waitingForHost => 'في انتظار بدء المضيف…';

  @override
  String get answerHint => 'إجابتك';

  @override
  String get submitAnswer => 'تأكيد (الإجابة + الرهان)';

  @override
  String get answerSaved => 'تم حفظ الإجابة';

  @override
  String get answerEdited => 'تم تعديل الإجابة — أعد التأكيد للحفظ';

  @override
  String wagerAmount(Object amount) {
    return 'الرهان $amount';
  }

  @override
  String get playerCorrect => 'إجابة صحيحة';

  @override
  String get playerIncorrect => 'إجابة خاطئة';

  @override
  String get hostStartNext => 'ابدأ / السؤال التالي';

  @override
  String get hostLock => 'قفل';

  @override
  String get hostLockLate => 'قفل (بعد المؤقت)';

  @override
  String get hostBoard => 'الترتيب';

  @override
  String get hostNext => 'السؤال التالي';

  @override
  String get hostFinish => 'إنهاء';

  @override
  String get gameStart => 'ابدأ اللعبة';

  @override
  String get correctAnswer => 'الإجابة الصحيحة:';

  @override
  String onlineCount(Object count) {
    return 'متصل: $count';
  }

  @override
  String playersCount(Object count, Object max) {
    return 'اللاعبون: $count / $max';
  }

  @override
  String minPlayersHint(Object count, Object max, Object min) {
    return 'اللاعبون: $count / $max — الحد الأدنى $min';
  }

  @override
  String get copyCode => 'نسخ الرمز';

  @override
  String get codeCopied => 'تم نسخ الرمز';

  @override
  String get loadingWagers => 'جارٍ تحميل الرهانات…';

  @override
  String get back => 'رجوع';

  @override
  String get statusLobby => 'الردهة';

  @override
  String get statusQuestionOpen => 'سؤال مفتوح';

  @override
  String get statusQuestionLocked => 'سؤال مقفل';

  @override
  String get statusReveal => 'الكشف';

  @override
  String get statusLeaderboard => 'الترتيب';

  @override
  String get statusFinalWager => 'الرهان الأخير';

  @override
  String get statusFinalReveal => 'الكشف الأخير';

  @override
  String get statusFinished => 'انتهت';

  @override
  String get gameLanguage => 'لغة اللعبة';

  @override
  String get editorTitleAr => 'العنوان بالعربية';

  @override
  String get editorDescAr => 'الوصف بالعربية';

  @override
  String get editorQuestionAr => 'السؤال بالعربية';

  @override
  String get editorAnswerAr => 'الإجابة بالعربية';

  @override
  String get editorAliasesAr => 'المرادفات بالعربية (واحد في كل سطر)';

  @override
  String get bootstrapErrorTitle => 'تعذر تشغيل Brainwager.';

  @override
  String get packImport => 'استيراد حزمة';

  @override
  String get packShareCode => 'رمز المشاركة';

  @override
  String get packOpen => 'فتح';

  @override
  String get sharedPack => 'حزمة مشتركة';

  @override
  String get packCreateWith => 'إنشاء لعبة بهذه الحزمة';

  @override
  String get copyShareLink => 'نسخ الرابط';

  @override
  String get linkCopied => 'تم نسخ الرابط';

  @override
  String get packReport => 'الإبلاغ';

  @override
  String get reportPackTitle => 'الإبلاغ عن الحزمة';

  @override
  String get reportReason => 'السبب';

  @override
  String get reportCancel => 'إلغاء';

  @override
  String get reportSend => 'إرسال';

  @override
  String get reportClose => 'إغلاق';

  @override
  String get packReported => 'تم الإبلاغ عن الحزمة';

  @override
  String get reportUpdated => 'تم تحديث البلاغ';

  @override
  String get invalidShareCode => 'رمز غير صالح (بصيغة PK-XXXX)';

  @override
  String get shopBuy => 'شراء';

  @override
  String shopBuyWithPrice(Object price) {
    return 'شراء · $price';
  }

  @override
  String get shopRestorePurchases => 'استعادة المشتريات';

  @override
  String get shopRefreshPurchases => 'تحديث المشتريات';

  @override
  String get shopOwned => 'مملوك';

  @override
  String get shopPurchasing => 'جارٍ الشراء…';

  @override
  String get shopPending => 'قيد الانتظار';

  @override
  String get shopSuccess => 'تم التحقق من الشراء';

  @override
  String get shopBackendUnavailable => 'المشتريات غير متاحة مؤقتًا';

  @override
  String get shopPlayUnavailable => 'متجر Play غير متاح';

  @override
  String get shopUnsupported => 'المشتريات متاحة على Android فقط';

  @override
  String get shopNoProducts => 'لا توجد منتجات مهيأة';

  @override
  String get shopRemoveAds => 'إزالة الإعلانات';

  @override
  String get shopCanceled => 'تم إلغاء الشراء';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navPacks => 'الحزم';

  @override
  String get navShop => 'المتجر';

  @override
  String get navProfile => 'الملف الشخصي';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileGuest => 'ضيف';

  @override
  String get profileAnonymous => 'مسجل الدخول كضيف';

  @override
  String get profileDisplayName => 'الاسم المعروض';

  @override
  String get profileLocale => 'اللغة';

  @override
  String get profileComingSoon => 'خيارات حساب إضافية قريبًا';

  @override
  String get profileAvatar => 'الصورة الرمزية';

  @override
  String get welcome => 'مرحبًا بك في Brainwager';

  @override
  String get chooseAvatar => 'اختر صورتك الرمزية';

  @override
  String get displayName => 'الاسم المعروض';

  @override
  String get saveProfile => 'حفظ الملف الشخصي';

  @override
  String get continueGuest => 'المتابعة كضيف';

  @override
  String get continueGoogle => 'المتابعة عبر Google';

  @override
  String get continueFacebook => 'المتابعة عبر Facebook';

  @override
  String get secureAccount => 'تأمين حسابي';

  @override
  String get secureAccountExplanation =>
      'اربط Google أو Facebook للاحتفاظ بتقدم هذا الضيف على جميع أجهزتك.';

  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟';

  @override
  String get existingAccountWarning =>
      'سيؤدي هذا إلى فتح حسابك الحالي بدل هذا الضيف المؤقت.';

  @override
  String get oauthPending => 'في انتظار المتصفح…';

  @override
  String get oauthUnavailable =>
      'تسجيل الدخول غير متاح حاليًا. تم الاحتفاظ بجلسة الضيف.';

  @override
  String get profileLoadError => 'تعذر تحميل الملف الشخصي';

  @override
  String get profileSaveError => 'تعذر حفظ الملف الشخصي';

  @override
  String get invalidDisplayName => 'يجب أن يكون الاسم من 2 إلى 20 حرفًا.';

  @override
  String get avatarLocked => 'هذه الصورة مقفلة.';

  @override
  String get accountGuest => 'حساب ضيف';

  @override
  String get accountConnected => 'حساب متصل';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String connectedWith(Object provider) {
    return 'متصل عبر $provider';
  }

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get avatarBrain => 'العقل';

  @override
  String get avatarRocket => 'الصاروخ';

  @override
  String get avatarStar => 'النجمة';

  @override
  String get avatarLightning => 'البرق';

  @override
  String get avatarPlanet => 'الكوكب';

  @override
  String get avatarTrophy => 'الكأس';

  @override
  String get avatarFootball => 'كرة القدم';

  @override
  String get avatarBasketball => 'كرة السلة';
}
