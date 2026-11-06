/// Configuración de acceso a la API.
///
/// Por defecto apunta al equipo host visto desde el emulador Android (10.0.2.2).
/// Para un celular físico: flutter run --dart-define=API_BASE_URL=`http://IP-LAN-PC:5000`
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:5000');

  static const String reimbursementsPath = '/api/reimbursements';

  static const Duration timeout = Duration(seconds: 10);

  /// Identificación simplificada: el empleado se elige al iniciar (el enunciado no exige login).
  static const List<String> employees = ['Empleado Demo', 'Ana Gómez', 'Carlos Pérez', 'Laura Martínez'];
}
