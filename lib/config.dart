/// Configurazione passata al build con --dart-define (vedi README).
/// Senza API_URL l'app parte in modalità demo.
class AppConfig {
  /// Indirizzo dell'API PHP, es. https://tuodominio.it/sfasciohub/api/
  /// Sul web può essere relativo al sito (es. "api/" oppure "../api/").
  static const apiUrl = String.fromEnvironment('API_URL');

  /// Indirizzo del sito pubblico, per i link "condividi" e "vedi sul sito".
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://charles1812.github.io/sfasciohub/');

  /// Mostra il pulsante "account di prova" anche con il server vero (dati di esempio caricati).
  static const demoLogin = bool.fromEnvironment('DEMO_LOGIN');

  static bool get hasServer => apiUrl.isNotEmpty;

  /// [siteUrl] come indirizzo assoluto (sul web può essere relativo).
  static String get site => Uri.base.resolve(siteUrl).toString();
}
