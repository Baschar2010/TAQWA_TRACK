import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Eine auswählbare Sprache. Die nativen Namen erscheinen in der Auswahl.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.englishName);

  final String code;
  final String nativeName;
  final String englishName;

  Locale get locale => Locale(code);
  bool get isRtl => code == 'ar' || code == 'ur' || code == 'fa';
}

const appLanguages = <AppLanguage>[
  AppLanguage('de', 'Deutsch', 'German'),
  AppLanguage('en', 'English', 'English'),
  AppLanguage('ar', 'العربية', 'Arabic'),
  AppLanguage('fr', 'Français', 'French'),
  AppLanguage('tr', 'Türkçe', 'Turkish'),
  AppLanguage('es', 'Español', 'Spanish'),
  AppLanguage('it', 'Italiano', 'Italian'),
  AppLanguage('pt', 'Português', 'Portuguese'),
  AppLanguage('nl', 'Nederlands', 'Dutch'),
  AppLanguage('ru', 'Русский', 'Russian'),
  AppLanguage('ur', 'اردو', 'Urdu'),
  AppLanguage('id', 'Bahasa Indonesia', 'Indonesian'),
  AppLanguage('ms', 'Bahasa Melayu', 'Malay'),
  AppLanguage('bn', 'বাংলা', 'Bengali'),
  AppLanguage('fa', 'فارسی', 'Persian'),
  AppLanguage('hi', 'हिन्दी', 'Hindi'),
  AppLanguage('zh', '中文', 'Chinese'),
  AppLanguage('ja', '日本語', 'Japanese'),
  AppLanguage('ko', '한국어', 'Korean'),
  AppLanguage('pl', 'Polski', 'Polish'),
  AppLanguage('uk', 'Українська', 'Ukrainian'),
  AppLanguage('sv', 'Svenska', 'Swedish'),
  AppLanguage('sq', 'Shqip', 'Albanian'),
  AppLanguage('bs', 'Bosanski', 'Bosnian'),
];

AppLanguage languageFor(String? code) {
  for (final language in appLanguages) {
    if (language.code == code) return language;
  }
  return appLanguages.first;
}

/// Übersetzungen für Onboarding und die wichtigsten Oberflächen.
/// Weitere Inhalte (Hadithe, Quran-Übersetzung) bleiben bewusst deutsch.
class AppText {
  const AppText({
    required this.welcome,
    required this.tagline,
    required this.featureOffline,
    required this.featureQuran,
    required this.featureFamily,
    required this.nameLabel,
    required this.nameHint,
    required this.languageLabel,
    required this.start,
    required this.privacyNote,
    required this.navHome,
    required this.navCalendar,
    required this.navFamily,
    required this.navPrayer,
    required this.navQibla,
    required this.greeting,
  });

  final String welcome;
  final String tagline;
  final String featureOffline;
  final String featureQuran;
  final String featureFamily;
  final String nameLabel;
  final String nameHint;
  final String languageLabel;
  final String start;
  final String privacyNote;
  final String navHome;
  final String navCalendar;
  final String navFamily;
  final String navPrayer;
  final String navQibla;
  final String greeting;

  static AppText of(String? code) => _texts[code] ?? _texts['en']!;

  static const _texts = <String, AppText>{
    'de': AppText(
      welcome: 'Willkommen bei TAQWA TRACK',
      tagline: 'Dein Gebet. Deine Gewohnheiten. Dein Quran.',
      featureOffline: '100 % offline – deine Daten bleiben auf dem Gerät',
      featureQuran: 'Quran, Hadithe und Gebetszeiten ohne Internet',
      featureFamily: 'Familie per QR-Code verbinden, ohne Konto',
      nameLabel: 'Wie dürfen wir dich nennen?',
      nameHint: 'Dein Name',
      languageLabel: 'Sprache',
      start: 'Los geht’s',
      privacyNote:
          'Mit dem Start stimmst du zu, dass alle Daten ausschließlich lokal gespeichert werden.',
      navHome: 'Home',
      navCalendar: 'Kalender',
      navFamily: 'Family',
      navPrayer: 'Gebete',
      navQibla: 'Qibla',
      greeting: 'As-salāmu ʿalaykum',
    ),
    'en': AppText(
      welcome: 'Welcome to TAQWA TRACK',
      tagline: 'Your prayer. Your habits. Your Quran.',
      featureOffline: '100% offline – your data stays on this device',
      featureQuran: 'Quran, hadith and prayer times without internet',
      featureFamily: 'Connect family by QR code, no account needed',
      nameLabel: 'What should we call you?',
      nameHint: 'Your name',
      languageLabel: 'Language',
      start: 'Get started',
      privacyNote:
          'By starting, you agree that all data is stored locally only.',
      navHome: 'Home',
      navCalendar: 'Calendar',
      navFamily: 'Family',
      navPrayer: 'Prayers',
      navQibla: 'Qibla',
      greeting: 'As-salamu alaykum',
    ),
    'ar': AppText(
      welcome: 'مرحبًا بك في تقوى تراك',
      tagline: 'صلاتك. عاداتك. قرآنك.',
      featureOffline: 'يعمل دون إنترنت – بياناتك تبقى على جهازك',
      featureQuran: 'القرآن والأحاديث وأوقات الصلاة دون إنترنت',
      featureFamily: 'اربط عائلتك برمز QR دون حساب',
      nameLabel: 'بماذا نناديك؟',
      nameHint: 'اسمك',
      languageLabel: 'اللغة',
      start: 'ابدأ',
      privacyNote: 'بالبدء فإنك توافق على أن جميع البيانات تُحفظ محليًا فقط.',
      navHome: 'الرئيسية',
      navCalendar: 'التقويم',
      navFamily: 'العائلة',
      navPrayer: 'الصلوات',
      navQibla: 'القبلة',
      greeting: 'السلام عليكم',
    ),
    'fr': AppText(
      welcome: 'Bienvenue sur TAQWA TRACK',
      tagline: 'Ta prière. Tes habitudes. Ton Coran.',
      featureOffline: '100 % hors ligne – tes données restent sur l’appareil',
      featureQuran: 'Coran, hadiths et horaires sans internet',
      featureFamily: 'Relie ta famille par QR code, sans compte',
      nameLabel: 'Comment devons-nous t’appeler ?',
      nameHint: 'Ton nom',
      languageLabel: 'Langue',
      start: 'Commencer',
      privacyNote:
          'En commençant, tu acceptes que toutes les données restent locales.',
      navHome: 'Accueil',
      navCalendar: 'Calendrier',
      navFamily: 'Famille',
      navPrayer: 'Prières',
      navQibla: 'Qibla',
      greeting: 'As-salamou alaykoum',
    ),
    'tr': AppText(
      welcome: 'TAQWA TRACK’e hoş geldin',
      tagline: 'Namazın. Alışkanlıkların. Kur’an’ın.',
      featureOffline: 'Tamamen çevrimdışı – verilerin cihazında kalır',
      featureQuran: 'Kur’an, hadis ve namaz vakitleri internetsiz',
      featureFamily: 'Aileni QR kod ile bağla, hesap gerekmez',
      nameLabel: 'Sana nasıl hitap edelim?',
      nameHint: 'Adın',
      languageLabel: 'Dil',
      start: 'Başla',
      privacyNote:
          'Başlayarak tüm verilerin yalnızca cihazda saklanmasını kabul edersin.',
      navHome: 'Ana sayfa',
      navCalendar: 'Takvim',
      navFamily: 'Aile',
      navPrayer: 'Namazlar',
      navQibla: 'Kıble',
      greeting: 'Selamün aleyküm',
    ),
    'es': AppText(
      welcome: 'Bienvenido a TAQWA TRACK',
      tagline: 'Tu oración. Tus hábitos. Tu Corán.',
      featureOffline: '100 % sin conexión – tus datos quedan en el dispositivo',
      featureQuran: 'Corán, hadices y horarios sin internet',
      featureFamily: 'Conecta a tu familia por QR, sin cuenta',
      nameLabel: '¿Cómo te llamamos?',
      nameHint: 'Tu nombre',
      languageLabel: 'Idioma',
      start: 'Empezar',
      privacyNote:
          'Al empezar aceptas que todos los datos se guardan solo localmente.',
      navHome: 'Inicio',
      navCalendar: 'Calendario',
      navFamily: 'Familia',
      navPrayer: 'Oraciones',
      navQibla: 'Qibla',
      greeting: 'As-salamu alaykum',
    ),
    'ru': AppText(
      welcome: 'Добро пожаловать в TAQWA TRACK',
      tagline: 'Твой намаз. Твои привычки. Твой Коран.',
      featureOffline: '100 % офлайн – данные остаются на устройстве',
      featureQuran: 'Коран, хадисы и время намаза без интернета',
      featureFamily: 'Свяжи семью по QR-коду, без аккаунта',
      nameLabel: 'Как к тебе обращаться?',
      nameHint: 'Твоё имя',
      languageLabel: 'Язык',
      start: 'Начать',
      privacyNote:
          'Начиная, ты соглашаешься, что все данные хранятся только локально.',
      navHome: 'Главная',
      navCalendar: 'Календарь',
      navFamily: 'Семья',
      navPrayer: 'Намазы',
      navQibla: 'Кибла',
      greeting: 'Ас-саляму алейкум',
    ),
    'zh': AppText(
      welcome: '欢迎使用 TAQWA TRACK',
      tagline: '你的礼拜。你的习惯。你的古兰经。',
      featureOffline: '完全离线 – 数据只保存在本机',
      featureQuran: '无需网络即可阅读古兰经、圣训和礼拜时间',
      featureFamily: '用二维码连接家人，无需账号',
      nameLabel: '我们该如何称呼你？',
      nameHint: '你的名字',
      languageLabel: '语言',
      start: '开始',
      privacyNote: '开始即表示你同意所有数据仅保存在本地。',
      navHome: '首页',
      navCalendar: '日历',
      navFamily: '家庭',
      navPrayer: '礼拜',
      navQibla: '朝向',
      greeting: '愿平安与你同在',
    ),
    'ur': AppText(
      welcome: 'TAQWA TRACK میں خوش آمدید',
      tagline: 'آپ کی نماز۔ آپ کی عادات۔ آپ کا قرآن۔',
      featureOffline: 'مکمل آف لائن – ڈیٹا صرف آپ کے فون پر رہتا ہے',
      featureQuran: 'قرآن، حدیث اور نماز کے اوقات بغیر انٹرنیٹ',
      featureFamily: 'اکاؤنٹ کے بغیر QR کوڈ سے خاندان کو جوڑیں',
      nameLabel: 'ہم آپ کو کیا کہیں؟',
      nameHint: 'آپ کا نام',
      languageLabel: 'زبان',
      start: 'شروع کریں',
      privacyNote:
          'شروع کرنے سے آپ مانتے ہیں کہ تمام ڈیٹا صرف مقامی طور پر محفوظ ہوگا۔',
      navHome: 'ہوم',
      navCalendar: 'کیلنڈر',
      navFamily: 'خاندان',
      navPrayer: 'نمازیں',
      navQibla: 'قبلہ',
      greeting: 'السلام علیکم',
    ),
    'id': AppText(
      welcome: 'Selamat datang di TAQWA TRACK',
      tagline: 'Shalatmu. Kebiasaanmu. Quranmu.',
      featureOffline: '100% offline – datamu tetap di perangkat',
      featureQuran: 'Quran, hadis, dan waktu shalat tanpa internet',
      featureFamily: 'Hubungkan keluarga dengan QR, tanpa akun',
      nameLabel: 'Kami panggil kamu apa?',
      nameHint: 'Namamu',
      languageLabel: 'Bahasa',
      start: 'Mulai',
      privacyNote:
          'Dengan memulai, kamu setuju semua data hanya disimpan secara lokal.',
      navHome: 'Beranda',
      navCalendar: 'Kalender',
      navFamily: 'Keluarga',
      navPrayer: 'Shalat',
      navQibla: 'Kiblat',
      greeting: 'Assalamu alaikum',
    ),
  };
}

/// Lädt die Datumsdaten für alle unterstützten Sprachen. Wird einmalig beim
/// Start aufgerufen, damit Datumsangaben überall in der App in der gewählten
/// Sprache erscheinen.
Future<void> initializeAppDateFormats() => initializeDateFormatting();

const _intlLocales = <String, String>{
  'de': 'de_DE',
  'en': 'en_US',
  'ar': 'ar_EG',
  'fr': 'fr_FR',
  'tr': 'tr_TR',
  'es': 'es_ES',
  'it': 'it_IT',
  'pt': 'pt_PT',
  'nl': 'nl_NL',
  'ru': 'ru_RU',
  'ur': 'ur_PK',
  'id': 'id_ID',
  'ms': 'ms_MY',
  'bn': 'bn_BD',
  'fa': 'fa_IR',
  'hi': 'hi_IN',
  'zh': 'zh_CN',
  'ja': 'ja_JP',
  'ko': 'ko_KR',
  'pl': 'pl_PL',
  'uk': 'uk_UA',
  'sv': 'sv_SE',
  'sq': 'sq_AL',
  'bs': 'bs_BA',
};

/// Passendes intl-Gebietsschema zu einem Sprachcode der App.
String intlLocaleFor(String? code) => _intlLocales[code] ?? 'en_US';

/// Passendes intl-Gebietsschema zur aktuell aktiven App-Sprache.
String intlLocaleOf(BuildContext context) =>
    intlLocaleFor(Localizations.localeOf(context).languageCode);

/// Formatiert ein Datum in der aktiven Sprache. Fehlt für eine Sprache die
/// intl-Datentabelle, wird englisch formatiert statt zu crashen.
String formatDate(BuildContext context, String pattern, DateTime date) {
  try {
    return DateFormat(pattern, intlLocaleOf(context)).format(date);
  } catch (_) {
    return DateFormat(pattern, 'en_US').format(date);
  }
}
