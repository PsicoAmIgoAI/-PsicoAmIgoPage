import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

// --- CONFIGURACIÓN DE SEGURIDAD Y SOPORTE ---
// La duración en días ha sido reemplazada por una fecha fija
final DateTime betaExpirationDate = DateTime.utc(2025, 11, 15, 23, 59, 59);

const int betaDurationDays = 14; // Mantenido para evitar errores en otras funciones si existieran, aunque ya no se usa para la lógica de expiración.
const String accessCode = '060608';
const String supportEmail = 'psicoamigosoporte@gmail.com';
const String suicideResponse = 'Lo siento, ocurrió un error.';

// 🚨 ENDPOINT SEGURO
const String chatEndpoint =
    'https://psicoamigo-proxy.psicoamigosoporte.workers.dev';

// --- TEMAS DE CONVERSACIÓN SUGERIDOS ---
final List<Map<String, String>> conversationTopics = [
  {
    'title': 'Manejo del Estrés',
    'prompt':
        'Me siento abrumado por el estrés diario. ¿Qué técnicas de manejo puedo aplicar ahora mismo?',
  },
  {
    'title': 'Mejorar el Sueño',
    'prompt':
        'Tengo problemas para dormir. ¿Me puedes dar consejos para mejorar mi higiene del sueño?',
  },
  {
    'title': 'Problema de Autoestima',
    'prompt': 'Quiero trabajar en mi autoestima. ¿Por dónde debería empezar?',
  },
  {
    'title': 'Técnicas de Relajación',
    'prompt':
        'Necesito una guía de respiración rápida para calmar mi ansiedad.',
  },
  {
    'title': 'Diario de Ánimo',
    'prompt':
        'Quiero empezar a llevar un diario de mi estado de ánimo. ¿Qué preguntas debo hacerme?',
  },
];

// --- LÍNEAS DE AYUDA (México) ---
final List<Map<String, dynamic>> emergencyLines = [
  {
    'name': 'CONADIC. Centro de Atención Ciudadana la Línea de la Vida',
    'phones': ['800 911 2000'],
    'schedule': '24 horas los 365 días.',
    'email': 'lalineadelavida@ssalud.gob.mx',
  },
  {
    'name': 'SAPTEL. Apoyo Psicológico Nacional',
    'phones': ['55 5259 8121'],
    'schedule': '24 horas los 365 días.',
    'email': 'saptel.crlyc@gmail.com',
  },
  {
    'name': 'SIMISAE. Centro Simi de Salud Emocional',
    'phones': ['800 911 3232'],
    'schedule': '24 horas los 365 días.',
    'email': 'centrodiagnostico@simisae.com.mx',
  },
  {
    'name': 'SALME. Instituto Jalisciense de Salud Mental',
    'phones': ['075', '33 2504 2020'],
    'schedule': '24 horas los 365 días.',
  },
  {
    'name': 'LOCATEL. Ayuda Ciudadana en Línea',
    'phones': ['*0311', '55 5658 1111'],
    'schedule':
        'Telefónica 24 horas y vía chat de 10:00 a 18:00 horas los 365 días.',
  },
  {
    'name': 'UNAM. Atención Psicológica a Distancia',
    'phones': ['55 5025 0855'],
    'schedule': 'De 9:00 a 18:00 horas.',
  },
  {
    'name':
        'Consejo Ciudadano para la Seguridad y Justicia de la Ciudad de México',
    'phones': ['55 5533 5533'],
    'schedule': '24 horas los 365 días.',
  },
  {
    'name': 'UAM. Apoyo Psicológico por Teléfono',
    'phones': ['55 2555 8092', '55 5804 6444', '55 3942 0339'],
    'schedule': 'Lunes a Viernes de 9:00 a 17:00 horas.',
  },
  {
    'name': 'ENEO - UNAM. Contención Emocional',
    'phones': ['55 5350 7218', '800 461 0098'],
    'schedule':
        'Lunes a Domingo de 9:00 a 14:00 horas y de 15:00 a 20:00 horas.',
  },
  {
    'name': 'Línea de Ayuda Origen',
    'phones': ['55 3234 8244', '800 015 1617'],
    'schedule': 'Lunes a Domingo de 8:00 a 22:00 horas.',
  },
  {
    'name': 'Servicio de Orientación Psicológica (S.O.S)',
    'phones': ['800 710 2496', '800 221 3109', '722 212 0532'],
    'schedule': 'Lunes a Viernes de 9:00 a 20:00 horas.',
  },
  {
    'name': 'Clínica E.M.A',
    'phones': ['961 236 7238', '961 236 7239', '961 236 7240'],
    'schedule': '24 horas los 365 días.',
  },
  {
    'name': 'Línea VIVETEL, Salva Vidas',
    'phones': ['066', '800 232 8432'],
    'schedule': 'Lunes a Viernes de 08:00 a 20:00 horas.',
  },
  {
    'name': 'Medicina a Distancia de la Secretaría de Salud',
    'phones': ['55 5132 0909'],
    'schedule': '24 horas los 365 días.',
  },
  {
    'name': 'Dinámica mente',
    'phones': ['800 290 0024'],
    'schedule': '24 horas los 365 días.',
  },
  {
    'name': 'Salvemos una Vida',
    'phones': ['99 9924 5991'],
    'schedule': '24 horas los 365 días.',
  },
];

// --- MODELOS DE DATOS ---
class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});

  Map<String, dynamic> toJson() => {'text': text, 'isUser': isUser};
  factory ChatMessage.fromJson(Map<String, dynamic> json) =>
      ChatMessage(text: json['text'] as String, isUser: json['isUser'] as bool);
}

class SavedChat {
  final String title;
  final String id;
  final List<ChatMessage> messages;

  SavedChat({required this.title, required this.id, required this.messages});

  Map<String, dynamic> toJson() => {
    'title': title,
    'id': id,
    'messages': messages.map((m) => m.toJson()).toList(),
  };
  factory SavedChat.fromJson(Map<String, dynamic> json) => SavedChat(
    title: json['title'] as String,
    id: json['id'] as String,
    messages: (json['messages'] as List)
        .map((i) => ChatMessage.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
}

// --- FUNCIONES UTILITARIAS ---

Future<void> launchPhone(String phoneNumber, BuildContext context) async {
  final Uri uri = Uri(scheme: 'tel', path: phoneNumber.replaceAll(' ', ''));
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo iniciar la llamada. El navegador debe tener permisos.',
            ),
          ),
        );
    }
  }
}

Future<void> launchMail(
  String email,
  BuildContext context, {
  String subject = '',
  String body = '',
}) async {
  final Uri uri = Uri(
    scheme: 'mailto',
    path: email,
    // Codificación para asegurar que el asunto y cuerpo funcionen
    query:
        'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
  );

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    // Si falla, da un mensaje claro al usuario
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo abrir la aplicación de correo. Intenta enviar un email manualmente a $email',
          ),
        ),
      );
    }
  }
}

// --- VISTA PRINCIPAL (MAIN) ---
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      title: 'PsicoAmIgo 🤖 (Beta)',
      debugShowCheckedModeBanner: false,
      // ELIMINACIÓN DE SPLASH SCREEN: Ir directamente a AccessControlScreen
      home: AccessControlScreen(), 
    ),
  );
}

// Pantalla de Carga (SplashScreen) - Mantenida para evitar errores de referencia
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3F448C), Color(0xFF5A61BD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFABBEEF)),
        ),
      ),
    );
  }
}


// 1. Control de Acceso (Duración Beta y Código Secreto)
class AccessControlScreen extends StatefulWidget {
  const AccessControlScreen({super.key});

  @override
  State<AccessControlScreen> createState() => _AccessControlScreenState();
}

class _AccessControlScreenState extends State<AccessControlScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isAccessGranted = false;
  String _message = 'Verificando acceso beta...';

  // Obtener la fecha de expiración desde las constantes globales
  final DateTime expirationDate = betaExpirationDate;


  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getInt('first_launch_timestamp');
    final termsAccepted = prefs.getBool('terms_accepted') ?? false;
    final userInfoCompleted = prefs.getBool('user_info_completed') ?? false;

    // 1. Obtener la fecha actual en UTC para comparación
    final now = DateTime.now().toUtc(); 

    // 2. Comprobar si la fecha actual ha pasado la fecha límite
    final bool isExpired = now.isAfter(expirationDate);

    if (firstLaunch == null) {
      // Primera vez: guarda el timestamp
      await prefs.setInt(
        'first_launch_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
    } 

    if (!isExpired) {
      // Acceso concedido si NO ha expirado
      _message = 'Acceso Beta concedido. La prueba finaliza el ${expirationDate.day}/${expirationDate.month}/${expirationDate.year}.';
      _isAccessGranted = true;
    } else {
      // Acceso denegado si YA expiró
      _message = 'El periodo Beta ha finalizado (expiró el ${expirationDate.day}/${expirationDate.month}/${expirationDate.year}). Por favor, introduce el código de acceso.';
      _isAccessGranted = false;
    }
    
    if (mounted) {
      setState(() {});
    }

    // Navegación si el acceso fue concedido
    if (_isAccessGranted) {
      if (termsAccepted) {
        if (userInfoCompleted) {
          _navigateToApp(); // 1. Acceso -> Términos Aceptados -> Datos Completados -> APP
        } else {
          _navigateToUserInfo(); // 2. Acceso -> Términos Aceptados -> Datos PENDIENTES -> UserInfo
        }
      } else {
        _navigateToTerms(); // 3. Acceso -> Términos PENDIENTES -> Términos
      }
    }
  }

  void _verifyCode() async {
    // La verificación del código ahora solo se usa para REINICIAR el acceso si está caducado
    if (_codeController.text == accessCode) {
      final prefs = await SharedPreferences.getInstance();

      // *** REINICIA EL TEMPORIZADOR para dar acceso nuevamente si el código es correcto ***
      await prefs.setInt(
        'first_launch_timestamp',
        DateTime.now().millisecondsSinceEpoch,
      );
      // ******************************************************

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Código correcto. Acceso concedido.',
            ),
          ),
        );
      }
      // Revisa si ya aceptó términos para ir a la siguiente pantalla (UserInfo)
      final termsAccepted = prefs.getBool('terms_accepted') ?? false;
      if (termsAccepted) {
          _navigateToUserInfo();
      } else {
          _navigateToTerms();
      }

    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Código incorrecto.')));
      }
    }
  }

  void _navigateToApp() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const PsicoAmIgoApp()));
  }

  void _navigateToTerms() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const TermsAndConditionsScreen()),
    );
  }

  // NUEVA FUNCIÓN DE NAVEGACIÓN
  void _navigateToUserInfo() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UserInfoScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control de Acceso Beta')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              if (!_isAccessGranted) ...[
                TextField(
                  controller: _codeController,
                  obscureText: true, // Ocultar código
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Código de Acceso Secreto',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _verifyCode,
                  child: const Text('Ingresar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// 2. Términos y Condiciones
class TermsAndConditionsScreen extends StatefulWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  State<TermsAndConditionsScreen> createState() =>
      _TermsAndConditionsScreenState();
}

class _TermsAndConditionsScreenState extends State<TermsAndConditionsScreen> {
  bool _agreed = false;

  void _acceptTerms() async {
    final prefs = await SharedPreferences.getInstance();

    if (_agreed) {
      await prefs.setBool('terms_accepted', true);
      if (mounted) {
        // Redirigir a la nueva pantalla de información de usuario
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UserInfoScreen()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debes aceptar los términos y condiciones para continuar.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y Condiciones Beta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Expanded(
              child: SingleChildScrollView(
                child: Text(
                  // Contenido simplificado y enfocado en la naturaleza beta
                  "AVISO IMPORTANTE: Esta es una aplicación en fase Beta (PsicoAmIgo Beta Testers). \n\n1. Naturaleza Experimental: Reconoces que la aplicación puede contener errores, fallos o no funcionar como se espera. \n\n2. Descargo de Responsabilidad Psicológica: PsicoAmIgo NO sustituye la atención médica o psicológica profesional. En caso de crisis o emergencia, contacta inmediatamente a los servicios de emergencia o las líneas de ayuda provistas. Los consejos de la IA son puramente informativos y de apoyo general.\n\n3. Duración: La aplicación está diseñada para operar bajo el programa Beta por un tiempo limitado, después del cual se requerirá un código.\n\n4. Privacidad: Los chats guardados se almacenan localmente en tu dispositivo.\n\nAl marcar la casilla, aceptas estas condiciones.",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            Row(
              children: [
                Checkbox(
                  value: _agreed,
                  onChanged: (bool? value) {
                    setState(() {
                      _agreed = value ?? false;
                    });
                  },
                ),
                const Text('Acepto los términos y condiciones'),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _acceptTerms,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Continuar a PsicoAmIgo'),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. NUEVA PANTALLA: Solicitud de Información del Usuario
class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _selectedGender;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    final gender = prefs.getString('user_gender');

    if (name != null) {
      _nameController.text = name;
    }
    if (gender != null) {
      _selectedGender = gender;
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedGender == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa tu nombre y selecciona tu género.')),
        );
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_gender', _selectedGender!);
    await prefs.setBool('user_info_completed', true); // Marca completado

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PsicoAmIgoApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración Inicial')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.person_pin, size: 80, color: Color(0xFF5A61BD)),
            const SizedBox(height: 20),
            const Text(
              '¡Casi listo! Necesitamos un par de datos para personalizar tu experiencia.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tu Nombre (o apodo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Selecciona tu género:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Género',
              ),
              items: const [
                DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                DropdownMenuItem(value: 'Otro/No especificar', child: Text('Otro/No especificar')),
              ],
              onChanged: (String? newValue) {
                setState(() {
                  _selectedGender = newValue;
                });
              },
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveAndContinue,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Comenzar a usar PsicoAmIgo'),
            ),
          ],
        ),
      ),
    );
  }
}


// --- VISTA DE LÍNEAS DE EMERGENCIA ---

class EmergencyLinesScreen extends StatelessWidget {
  const EmergencyLinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Líneas de Ayuda y Emergencia')),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: emergencyLines.length,
        itemBuilder: (context, index) {
          final line = emergencyLines[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF5A61BD),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.black12),
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: (line['phones'] as List<String>).map((phone) {
                      return ElevatedButton.icon(
                        onPressed: () => launchPhone(phone, context),
                        icon: const Icon(Icons.phone, size: 16),
                        label: Text(phone),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.redAccent, // Botón Rojo solicitado
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (line['email'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.email, size: 16, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            line['email']!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      line['schedule']!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// --- PANTALLA DE REPORTE ---

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  void _sendEmail(BuildContext context, String subject) async {
    final TextEditingController bodyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) {
        // Usamos dialogContext para el pop
        return AlertDialog(
          title: Text(subject == 'Fallo' ? 'Reportar Fallo' : 'Sugerencia'),
          content: TextField(
            decoration: InputDecoration(
              hintText: subject == 'Fallo'
                  ? 'Describe el fallo encontrado...'
                  : 'Describe tu sugerencia...',
              border: const OutlineInputBorder(),
            ),
            controller: bodyController,
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Cierra el diálogo
                launchMail(
                  supportEmail,
                  context, // Pasa el contexto para mostrar el SnackBar de error
                  subject: 'Reporte Beta - $subject',
                  body: bodyController.text,
                );
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar y Sugerencias')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Botón de Reporte de FALLO (solo texto, color ajustado)
            ElevatedButton(
              onPressed: () => _sendEmail(context, 'Fallo'),
              child: const Text('Reportar Fallo por Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9CA2EF), // Color más claro
                foregroundColor: Colors.white, // Texto blanco para ambos temas
                minimumSize: const Size(
                  250,
                  50,
                ), // Tamaño fijo para mejor estética
              ),
            ),
            const SizedBox(height: 20),
            // Botón de SUGERENCIA (solo texto, color ajustado)
            ElevatedButton(
              onPressed: () => _sendEmail(context, 'Sugerencia'),
              child: const Text('Enviar Sugerencia por Email'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7178DF), // Color intermedio
                foregroundColor: Colors.white, // Texto blanco para ambos temas
                minimumSize: const Size(
                  250,
                  50,
                ), // Tamaño fijo para mejor estética
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'Los reportes se envían a $supportEmail o al grupo oficial PsicoAmigo.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MODALES Y DIÁLOGOS ---

// Modal para manejar crisis de suicidio
Future<void> showEmergencyModal(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('¡Estamos aquí para ayudarte!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Si te encuentras en una emergencia o crisis, por favor contacta a un profesional inmediatamente:',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Text(
              'Emergencias: 911',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontSize: 18,
              ),
            ),
            Text(
              'Línea de la Vida: 800 911 2000',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el modal de emergencia
              _showCallConfirmation(context, '8009112000', 'Línea de la Vida');
            },
            icon: const Icon(Icons.phone),
            label: const Text('Llamar a Línea de la Vida'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          ),
        ],
      );
    },
  );
}

// Modal de confirmación antes de llamar
void _showCallConfirmation(BuildContext context, String number, String name) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Confirmar Llamada a $name'),
        content: Text('¿Estás seguro de que deseas llamar a $name ($number)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cierra el modal de confirmación
              launchPhone(number, context);
            },
            child: const Text('Llamar'),
          ),
        ],
      );
    },
  );
}

// Modal para guardar chat
Future<void> showSaveChatModal(
  BuildContext context,
  List<ChatMessage> messages,
  Function(SavedChat) onSave,
) async {
  final TextEditingController titleController = TextEditingController();
  await showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Guardar Chat (Archivar)'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Nombre para archivar este chat'),
          controller: titleController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim().isEmpty
                  ? 'Chat archivado ${DateTime.now().hour}:${DateTime.now().minute}'
                  : titleController.text.trim();
              final newChat = SavedChat(
                title: title,
                // El nuevo ID asegura que se guarde como un chat "archivado" nuevo
                id: DateTime.now().microsecondsSinceEpoch.toString(), 
                messages: List.from(messages),
              );
              onSave(newChat);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Archivar'),
          ),
        ],
      );
    },
  );
}

// --- WIDGET PARA LA ANIMACIÓN DE "TYPING" ---
class TypingIndicator extends StatefulWidget {
  final Color dotColor;
  const TypingIndicator({super.key, required this.dotColor});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _dotAnimations = List.generate(
      3,
      (i) => Tween(begin: -2.0, end: 2.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            (i * 0.25),
            (i * 0.25) + 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return Transform.translate(
              offset: Offset(0, _dotAnimations[i].value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// --- GESTIÓN DE CHATS (HOMESCREEN) ---

class PsicoAmIgoApp extends StatefulWidget {
  const PsicoAmIgoApp({super.key});

  @override
  State<PsicoAmIgoApp> createState() => _PsicoAmIgoAppState();
}

class _PsicoAmIgoAppState extends State<PsicoAmIgoApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Obtener la preferencia guardada por el usuario
    final storedDarkMode = prefs.getBool('dark_mode');

    // 2. Determinar el tema del sistema (solo si no hay preferencia guardada)
    // CLAVE: Usa platformBrightness para leer la preferencia del SO
    final bool systemDarkMode = 
        (storedDarkMode == null) && 
        (MediaQuery.of(context).platformBrightness == Brightness.dark);

    if (mounted) {
      setState(() {
        // Usar el tema guardado, si no, usar el tema del sistema, si no, usar falso (modo claro por defecto)
        _isDarkMode = storedDarkMode ?? systemDarkMode;
      });
    }
  }

  void toggleTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    // Guardar la preferencia explícita del usuario
    await prefs.setBool('dark_mode', value); 
    if (mounted) {
      setState(() {
        _isDarkMode = value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Definición del estilo base para botones
    final baseButtonStyle = ButtonStyle(
      // Usar WidgetStateProperty.all en lugar de MaterialStateProperty.all (deprecado)
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    );
    
    // Tema Claro ColorScheme
    final lightColorScheme = const ColorScheme.light(
          primary: Color(0xFF3F448C),
          onPrimary: Colors.white,
          secondary: Color(0xFF9CA2EF),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
    );

    // Tema Oscuro ColorScheme
    final darkColorScheme = const ColorScheme.dark(
          primary: Color(0xFF7178DF),
          onPrimary: Colors.white,
          secondary: Color(0xFFABBEEF),
          onSecondary: Colors.white,
          surface: Color(0xFF2C2E2E),
          onSurface: Colors.white70,
    );

    return MaterialApp(
      title: 'PsicoAmIgo',
      debugShowCheckedModeBanner: false,
      // Temas (Claro y Oscuro)
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF3F448C),
        scaffoldBackgroundColor: const Color(0xFFECEFF1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF5A61BD),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: lightColorScheme,
        // CardTheme usa la clase CardThemeData()
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: baseButtonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF5A61BD)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF5A61BD), // Color del texto del botón
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        // Estilo para el input de texto en el chat
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: TextStyle(color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: const BorderSide(color: Color(0xFF5A61BD), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide(color: Colors.grey[400]!, width: 1.0),
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        // 🚨 COLOR DE FONDO OSCURO SOLICITADO (#1b1c1c)
        scaffoldBackgroundColor: const Color(0xFF1b1c1c), 
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3F448C), // Un azul más oscuro para AppBar en Dark Mode
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        colorScheme: darkColorScheme,
        cardTheme: CardThemeData(
          color: const Color(0xFF2C2E2E), // Tarjetas más oscuras
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: baseButtonStyle.copyWith(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF7178DF)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFABBEEF),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        // Estilo para el input de texto en el chat
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2E2E),
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: const BorderSide(color: Color(0xFFABBEEF), width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide(color: Colors.grey[700]!, width: 1.0),
          ),
        ),
      ),
      // CLAVE: Usar themeMode para aplicar el tema determinado en _isDarkMode
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: HomeScreen(isDarkMode: _isDarkMode, onThemeChanged: toggleTheme),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;
  const HomeScreen({
    required this.isDarkMode,
    required this.onThemeChanged,
    super.key,
  });
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  List<ChatMessage> _messages = [];
  List<SavedChat> _savedChats = []; // Contiene SOLO los chats archivados
  bool _isChatLocked = false; 

  // ID especial para la conversación activa que se guarda automáticamente
  static const String currentChatId = 'CURRENT_ACTIVE_CHAT'; 

  // Variables para la información del usuario
  String _userName = 'Amigo';
  String _userGender = 'Neutral';

  @override
  void initState() {
    super.initState();
    _loadUserInfoAndChats(); // Cargar ambos al inicio
  }

  Future<void> _loadUserInfoAndChats() async {
    final prefs = await SharedPreferences.getInstance();
    
    final name = prefs.getString('user_name') ?? 'Amigo';
    final gender = prefs.getString('user_gender') ?? 'Neutral';

    if (mounted) {
      setState(() {
        _userName = name;
        _userGender = gender;
      });
    }

    _loadSavedChats(prefs);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Función para desplazar el chat al final
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- PERSISTENCIA DE CHATS ---

  Future<void> _loadSavedChats([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    final chatStrings = prefs.getStringList('saved_chats') ?? [];
    
    final List<SavedChat> loadedChats = chatStrings
        .map(
          (s) => SavedChat.fromJson(json.decode(s) as Map<String, dynamic>),
        )
        .toList();
        
    // 1. Encontrar el chat activo
    final activeChat = loadedChats.firstWhereOrNull(
      (chat) => chat.id == currentChatId,
    );

    if (mounted) {
      setState(() {
        // 2. Guardar SOLAMENTE los chats archivados en _savedChats
        _savedChats = loadedChats.where((chat) => chat.id != currentChatId).toList();
        
        // 3. Cargar el chat activo en _messages (si existe y tiene contenido)
        if (activeChat != null && activeChat.messages.isNotEmpty) {
          _messages = activeChat.messages;
          _isChatLocked = false;
          _scrollToBottom();
        }
      });
    }
  }
  
  // FUNCIÓN CLAVE: Guardado Automático Mensaje a Mensaje
  Future<void> _autoSaveCurrentChat() async {
    // Si la conversación está vacía (recién iniciada), no guardamos
    if (_messages.isEmpty) return; 

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Construir el objeto del chat activo
    final currentChat = SavedChat(
        title: 'Chat Activo (Guardado Automático)', 
        id: currentChatId, 
        messages: List.from(_messages),
    );

    // 2. Combinar: Chats archivados (_savedChats) + Chat activo (currentChat)
    // Usamos _savedChats que SOLO contiene los archivados.
    final List<SavedChat> chatsToSave = List.from(_savedChats);
    chatsToSave.add(currentChat);

    // 3. Guardar la lista combinada
    final newChatStrings = chatsToSave
        .map((c) => json.encode(c.toJson()))
        .toList();
        
    await prefs.setStringList('saved_chats', newChatStrings);
  }

  // Función de Archivar Chat (Crea un chat nuevo y vacía el activo)
  Future<void> _saveChat(SavedChat newChat) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Añadir el nuevo chat 'archivado'
    _savedChats.add(newChat);
    
    // 2. Crear un chat activo vacío para sobrescribir la versión persistente
    final emptyActiveChat = SavedChat(
      title: 'Chat Activo (Guardado Automático)',
      id: currentChatId,
      messages: [],
    );
    
    // 3. Reconstruir la lista de persistencia: Archivados + Chat activo vacío
    final List<SavedChat> chatsToSave = List.from(_savedChats);
    chatsToSave.add(emptyActiveChat); 

    // 4. Guardar
    final chatStrings = chatsToSave
        .map((c) => json.encode(c.toJson()))
        .toList();
        
    await prefs.setStringList('saved_chats', chatStrings);
    
    // 5. Limpiar la conversación actual y recargar la lista de archivados
    if (mounted) {
      setState(() {
        _messages = [];
        _isChatLocked = false;
      });
    }

    // Forzar la recarga del estado local para actualizar el Drawer
    _loadSavedChats(prefs);

    // Mostrar Snackbar y cerrar Drawer
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat "${newChat.title}" archivado. ¡Nuevo chat iniciado!')),
      );
      Navigator.of(context).pop(); 
    }
  }

  void _deleteChat(String id) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Eliminar el chat de la lista local
    if (mounted) {
      setState(() {
        _savedChats.removeWhere((chat) => chat.id == id);
      });
    }
    
    // Si el chat eliminado era el activo, vaciamos la vista
    if (id == currentChatId) {
       if (mounted) {
          setState(() {
            _messages = [];
          });
       }
       // Si era el chat activo, necesitamos asegurarnos de que la versión vacía se guarde para persistencia
       _autoSaveCurrentChat(); 
       // Forzar la recarga del estado local para asegurar que _savedChats esté limpio
       _loadSavedChats(prefs);
       return;
    }

    // Para chats archivados: Reconstruir la lista de persistencia (Chats archivados + Chat activo)
    final activeChat = SavedChat(
      title: 'Chat Activo (Guardado Automático)',
      id: currentChatId,
      messages: _messages,
    );
    
    final List<SavedChat> chatsToSave = List.from(_savedChats);
    chatsToSave.add(activeChat);

    final chatStrings = chatsToSave
        .map((c) => json.encode(c.toJson()))
        .toList();
        
    await prefs.setStringList('saved_chats', chatStrings);
    
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat eliminado.')));
    }
    
    _loadSavedChats(prefs);
  }

  void _loadChat(List<ChatMessage> messages) {
    if (mounted) {
      setState(() {
        _messages = messages;
        _isChatLocked = false; 
      });
      Navigator.of(context).pop(); // Cierra el Drawer
      _scrollToBottom();
    }
  }

  void _startNewChat() {
    if (mounted) {
      setState(() {
        _messages = [];
        _isChatLocked = false; 
      });
      // Forzamos un guardado para que el 'Chat Activo' se quede vacío en la persistencia
      _autoSaveCurrentChat(); 
      Navigator.of(context).pop(); // Cierra el Drawer
    }
  }

  // --- LÓGICA DEL CHATBOT ---

  Future<void> sendMessage(String message) async {
    if (message.trim().isEmpty || _isChatLocked) return;

    final lowerCaseMessage = message.toLowerCase();

    // 1. DETECCIÓN DE CRISIS
    final bool isSuicideOrViolence =
        lowerCaseMessage.contains('suicid') ||
        lowerCaseMessage.contains('morir') ||
        lowerCaseMessage.contains('me quiero morir') ||
        lowerCaseMessage.contains('matarme') ||
        lowerCaseMessage.contains('ya no quiero vivir') ||
        lowerCaseMessage.contains('voy a herir a alguien');

    if (isSuicideOrViolence) {
      await showEmergencyModal(context);
      _controller.clear();
      if (mounted) {
        setState(() {
          _isChatLocked = true;
        });
      }
      return;
    }

    // 2. Detección de "Gracias" (Archivar Chat)
    if (lowerCaseMessage.trim() == 'gracias') {
      _controller.clear();
      if (_messages.length > 2) { // Asegurarse de que haya habido intercambio
        await showSaveChatModal(context, _messages, (chat) {
            _saveChat(chat);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inicia una conversación primero.')),
          );
        }
      }
      return;
    }

    if (mounted) {
      setState(() {
        final capMessage =
            message.substring(0, 1).toUpperCase() + message.substring(1);
        _messages.add(ChatMessage(text: capMessage, isUser: true));
        _isLoading = true;
      });
    }
    _scrollToBottom();
    _controller.clear();

    final historyLength = _messages.length > 10 ? _messages.length - 10 : 0;
    final contextMessages = _messages.sublist(historyLength);

    const endpoint = chatEndpoint; 

    try {
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'z-ai/glm-4.5-air:free',
          'messages': [
            {
              'role': 'system',
              'content':
                  'Eres un amigo terapeuta llamado PsicoAmIgo que brinda apoyo emocional y psicológico de manera empática y amable. Tu usuario se llama $_userName y su género es $_userGender. En ningún momento te saldrás de tu papel y ten en claro que no buscas sustituir a un profesional, solo complementar.',
            },
            ...contextMessages.map(
              (m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              },
            ),
          ],
        }),
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['choices'] != null && body['choices'].isNotEmpty) {
          final reply = body['choices'][0]['message']['content'].trim();

          if (mounted) {
            setState(() {
              _messages.add(ChatMessage(text: reply, isUser: false));
              _isLoading = false;
            });
          }
          _scrollToBottom();
          
          // ¡GUARDADO AUTOMÁTICO DESPUÉS DE LA RESPUESTA DE LA IA!
          _autoSaveCurrentChat();
          
        } else {
          _handleApiError('Respuesta de IA vacía.');
        }
      } else if (response.statusCode == 402) {
        _handleApiError('Error de estado 402: Falla de api.');
      } else {
        _handleApiError('Error de estado: ${response.statusCode}');
      }
    } catch (e) {
      _handleApiError('Error de red, intenta de nuevo.');
    }
  }

  void _handleApiError(String message) {
    if (mounted) {
      setState(() {
        String displayMessage;
        if (message.contains('402')) {
          displayMessage =
              'Error de servicio (402). El equipo de PsicoAmIgo está recargando el servicio de IA. El servicio se restaurará pronto. Disculpa las molestias.';
        } else if (message.contains('Error de red')) {
          displayMessage =
              'Lo siento, ocurrió un error de conexión. Por favor, inténtalo de nuevo. Si el problema persiste, contacta al equipo de PsicoAmIgo.';
        } else {
          displayMessage =
              'Ha ocurrido un error inesperado. El equipo de PsicoAmIgo ha sido notificado.';
        }

        _messages.add(ChatMessage(text: displayMessage, isUser: false));
        _isLoading = false;
      });
    }
    _scrollToBottom();
    _autoSaveCurrentChat(); // Guardar el mensaje de error para persistencia
  }

  // --- WIDGETS DE UI ---

  List<SavedChat> _getChatsForDrawer() {
    final List<SavedChat> drawerChats = [];
    
    // 1. Añadir el chat activo si tiene mensajes
    if (_messages.isNotEmpty) {
      drawerChats.add(SavedChat(
        title: 'Chat Activo (Guardado Automático)',
        id: currentChatId,
        messages: _messages,
      ));
    }
    // 2. Añadir los chats archivados (que es lo que ya contiene _savedChats)
    drawerChats.addAll(_savedChats);
    
    return drawerChats;
  }

  List<TextSpan> _parseStructuredText(String text) {
    final List<TextSpan> spans = [];
    final RegExp boldRegExp = RegExp(r'\*\*(.*?)\*\*');
    final List<String> lines = text.split(RegExp(r'(?:<br>|\n\*\s*)')); // Añadido \n* para listas

    for (String line in lines) {
      if (line.trim().isEmpty) continue;

      // Detectar si es un elemento de lista (empieza con * o número seguido de punto)
      if (line.trim().startsWith('* ') || RegExp(r'^\d+\.\s+').hasMatch(line.trim())) {
        line = line.trim().replaceFirst(RegExp(r'^\*?\s*(\d+\.)?\s*'), '').trim();
        spans.add(const TextSpan(text: '\n• ')); // Usamos viñetas
      } else if (spans.isNotEmpty && !spans.last.text!.endsWith('\n')) {
        spans.add(const TextSpan(text: '\n')); // Salto de línea entre párrafos
      }

      int lastMatchEnd = 0;

      for (final match in boldRegExp.allMatches(line)) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: line.substring(lastMatchEnd, match.start)));
        }

        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        );

        lastMatchEnd = match.end;
      }

      if (lastMatchEnd < line.length) {
        spans.add(TextSpan(text: line.substring(lastMatchEnd)));
      }
    }

    // Eliminar el primer salto de línea si no es necesario
    if (spans.isNotEmpty && spans[0].text == '\n') {
      spans.removeAt(0);
    }
    // Asegurar un salto de línea al final si no es una lista
    if (spans.isNotEmpty && !spans.last.text!.endsWith('\n')) {
      spans.add(const TextSpan(text: '\n'));
    }

    return spans;
  }

  Widget _buildChatDrawer() {
    final chatsForDrawer = _getChatsForDrawer();
    
    return Drawer(
      child: Container(
        color: Theme.of(context).cardColor, // Usar color de tarjeta para el drawer
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 28),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Historial de Chats',
                        style: TextStyle(color: Colors.white, fontSize: 24),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Usuario: $_userName',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
              title: Text('Iniciar Nuevo Chat', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: _startNewChat,
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            Expanded(
              child: chatsForDrawer.isEmpty
                  ? Center(child: Text('Inicia una conversación para ver el historial.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))))
                  : ListView.builder(
                      itemCount: chatsForDrawer.length,
                      itemBuilder: (context, index) {
                        final chat = chatsForDrawer[index];
                        final isCurrentChat = chat.id == currentChatId;
                        
                        return Card( // Usamos Card para cada elemento del historial
                          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          elevation: 1,
                          child: ListTile(
                            leading: isCurrentChat 
                                ? Icon(Icons.mode_edit, color: Theme.of(context).colorScheme.secondary) 
                                : Icon(Icons.chat_bubble_outline, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                            title: Text(
                              chat.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            subtitle: Text('${chat.messages.length} mensajes', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            onTap: () => _loadChat(chat.messages),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _deleteChat(chat.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Divider(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
            ListTile(
              leading: Icon(Icons.bug_report, color: Theme.of(context).colorScheme.primary),
              title: Text('Reportar Fallo / Sugerencia', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop(); 
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ReportScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_phone, color: Colors.redAccent),
              title: Text('Líneas de Emergencia', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop(); 
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const EmergencyLinesScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    if (_messages.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ilustración de PsicoAmIgo
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Icon(
                    Icons.psychology, // Icono de cerebro o psicología
                    size: 100,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                Text(
                  '¡Hola $_userName! Soy PsicoAmIgo, tu asistente de bienestar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface, // Usar onSurface
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Estoy aquí para escucharte y apoyarte en tu camino hacia una mente más feliz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8), // Usar onSurface
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Puedes empezar con estos temas:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: conversationTopics.map((topic) {
                    return ActionChip(
                      onPressed: () {
                        sendMessage(topic['prompt']!);
                      },
                      label: Text(topic['title']!),
                      labelStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'O simplemente escribe lo que tengas en mente abajo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)), // Usar onSurface
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      // Degradado de fondo para el área de chat
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isDarkMode
              ? [const Color(0xFF1b1c1c), const Color(0xFF2C2E2E)] // Degradado oscuro
              : [const Color(0xFFECEFF1), const Color(0xFFF5F5F5)], // Degradado claro
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: message.isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!message.isUser) // Avatar de PsicoAmIgo
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    child: Icon(Icons.psychology, size: 20, color: Theme.of(context).colorScheme.onSecondary),
                  ),
                SizedBox(width: message.isUser ? 0 : 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message.isUser
                          ? Theme.of(context).colorScheme.primary // Color para el usuario
                          : Theme.of(context).colorScheme.surface, // Color para la IA
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                        bottomRight: Radius.circular(message.isUser ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: message.isUser ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        children: _parseStructuredText(message.text),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: message.isUser ? 8 : 0),
                if (message.isUser) // Avatar del Usuario
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.onPrimary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PsicoAmIgo - Chat IA'),
        actions: [
          // BOTÓN DE EMERGENCIA ELIMINADO DEL APPBAR AQUÍ
          Row(
            children: [
              Icon(
                widget.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: Colors.white,
              ),
              Switch(
                value: widget.isDarkMode,
                onChanged: widget.onThemeChanged,
                activeColor: Colors.white,
                inactiveThumbColor: Colors.grey[300],
                inactiveTrackColor: Colors.grey[600],
              ),
              const SizedBox(width: 12),
            ],
          ),
        ],
      ),
      drawer: _buildChatDrawer(), // Menú lateral para chats guardados
      body: Column(
        children: [
          Expanded(
            child: _buildChatContent(), // Muestra el chat o los temas sugeridos
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TypingIndicator(dotColor: Theme.of(context).colorScheme.secondary),
            ),
          // Barra de entrada de texto (envuelta en Card o Container para mejor estilo)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor, // Usa el color de superficie para la barra
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Botón de ARCHIVAR MANUALMENTE (Guardar)
                if (!_isChatLocked && _messages.isNotEmpty) 
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton(
                      onPressed: (!_isLoading)
                          ? () =>
                              showSaveChatModal(context, _messages, (chat) {
                                _saveChat(chat);
                              })
                          : null,
                      child: const Icon(Icons.archive), // Icono de archivar
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        minimumSize: const Size(50, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_isChatLocked,
                    // Usamos el decoration del tema
                    decoration: InputDecoration(
                      hintText: _isChatLocked
                          ? "Conversación Bloqueada. Llama al 911."
                          : 'Escribe tu mensaje o "gracias" para archivar...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      // El resto del estilo viene del tema principal
                    ),
                    onSubmitted: sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isChatLocked
                      ? null
                      : () => sendMessage(_controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary, // Un color de acento
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                    minimumSize: const Size(50, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pequeña extensión para el manejo de listas, útil para buscar el chat activo
extension ListExtension<T> on List<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}