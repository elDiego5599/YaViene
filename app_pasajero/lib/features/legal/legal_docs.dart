/// Los dos documentos que el pasajero acepta antes de entrar al mapa.
///
/// El texto vive aquí dentro y no se descarga: la bienvenida es lo primero
/// que se abre, a veces con el teléfono sin datos, y un documento que no
/// carga no se puede aceptar. Abrirlos en el navegador tampoco sirve —eso
/// pide `url_launcher`, un plugin más, y saca al usuario de la app justo
/// antes del sí—, así que se leen en una pantalla propia.
///
/// La misma copia está publicada en la web (`privacidad.html` y
/// `terminos.html` de YaVieneWeb) y las dos tienen que decir lo mismo:
/// cambiar una y no la otra deja al usuario aceptando un texto distinto del
/// que se publica. Si el cambio es de fondo, sube también [kLegalVersion]:
/// eso es lo que hace que la app vuelva a preguntar.
library;

/// Qué es cada trozo de un documento. No hay negritas ni enlaces: un
/// documento legal se lee de arriba abajo y lo único que necesita es saber
/// dónde empieza cada sección.
enum LegalBlockKind { heading, paragraph, bullet }

class LegalBlock {
  final LegalBlockKind kind;
  final String text;

  const LegalBlock.heading(this.text) : kind = LegalBlockKind.heading;
  const LegalBlock.p(this.text) : kind = LegalBlockKind.paragraph;
  const LegalBlock.bullet(this.text) : kind = LegalBlockKind.bullet;
}

class LegalDoc {
  /// El trozo de camino con el que se abre: `/legal/privacidad`.
  final String id;
  final String title;

  /// La fecha del texto, dicha como la dice la web.
  final String updated;
  final List<LegalBlock> blocks;

  const LegalDoc({
    required this.id,
    required this.title,
    required this.updated,
    required this.blocks,
  });
}

/// Versión de los documentos que el usuario acepta.
///
/// Sube cuando cambie algo de fondo —qué se guarda, qué viaja, qué se
/// promete—, no cuando se corrija una coma: cada subida vuelve a poner la
/// bienvenida delante de todo el mundo.
// Sube a 2 el 19 de septiembre de 2026: la privacidad pasa a decir qué
// ocurre cuando sales de la app —que el seguimiento sigue pero la ubicación
// no— y eso es parte de lo que se promete, así que el sí que se dio sobre el
// texto anterior no vale para este.
// Sube a 3 el 29 de septiembre de 2026: el seguimiento de Android ya no
// sigue con la app cerrada del todo, solo con la app en el fondo y un aviso
// armado (auditoría 2026-09, H1). Lo prometido cambió otra vez.
// Sube a 4 el 2 de octubre de 2026: en Android, con un aviso armado, el punto
// de espera redondeado y el código de Firebase Cloud Messaging van al
// servidor para que el aviso suene con la app cerrada (D13 del backend).
// Hasta aquí la ubicación no salía nunca del teléfono; ahora sale en ese caso.
const int kLegalVersion = 4;

const LegalDoc legalPrivacidad = LegalDoc(
  id: 'privacidad',
  title: 'Privacidad',
  updated: '2 de octubre de 2026',
  blocks: [
    LegalBlock.p(
      'Ya Viene es una aplicación para saber por dónde va tu bus. Para eso '
      'necesita muy poco, y lo poco que necesita casi todo se queda dentro '
      'de tu teléfono. Esto dice exactamente qué es cada cosa.',
    ),
    LegalBlock.heading('Tu ubicación se queda en el teléfono, salvo una vez'),
    LegalBlock.p(
      'La app te pide permiso de ubicación para dos cosas: centrar el mapa '
      'donde estás y calcular cuántos metros te separan del bus. Las dos se '
      'hacen dentro del aparato.',
    ),
    LegalBlock.p(
      'Para ver los buses, lo único que tu teléfono le pide al servidor es '
      '«mándame las posiciones de esta ruta». Dónde estás tú no viaja en esa '
      'petición.',
    ),
    // El único caso en que la ubicación sale (D13 del backend): el punto se
    // redondea a tres decimales en `avisos_push.dart` y el servidor borra la
    // fila al quitar el aviso, cuando la app ve que sonó o al vencer.
    LegalBlock.p(
      'La excepción es el aviso en Android, para que suene con la app '
      'cerrada. Mientras tienes uno armado, tu teléfono le deja al servidor el '
      'punto desde el que esperas —el que marcaste a mano o tu última '
      'posición—, redondeado a unos 100 metros, y lo pone al día cada 20 '
      'segundos mientras la app está abierta. Con él van el bus y la ruta del '
      'aviso y el código con el que Firebase Cloud Messaging le hace llegar la '
      'notificación a tu teléfono. Se borra cuando quitas el aviso o cuando la '
      'app ve que sonó, y como mucho a las tres horas de armarlo. No se '
      'comparte con la empresa de transporte ni con nadie más. En iPhone tu '
      'ubicación no sale del teléfono.',
    ),
    LegalBlock.heading('El aviso lo calcula tu propio teléfono'),
    LegalBlock.p(
      'Cuando activas el aviso, la app compara tu posición con la del bus '
      'mientras lo ves moverse, y cuando entra en un kilómetro a la redonda '
      'lanza una notificación local —la crea el teléfono, no la manda un '
      'servidor—. Solo si cierras la app en Android mide el servidor, con el '
      'punto de arriba, y la notificación llega por Firebase Cloud Messaging.',
    ),
    LegalBlock.p(
      'Cuando sales de la app sin cerrarla y tienes un aviso activo, en '
      'Android el seguimiento sigue vivo —verás una notificación fija que lo '
      'dice— pero tu ubicación deja de actualizarse: la app pide el permiso '
      'de ubicación «solo mientras la uso» y no el de segundo plano, así que '
      'la distancia se mide contra el último punto que conoció, o contra el '
      'punto de espera que hayas marcado a mano. Si cierras la app del todo, '
      'el seguimiento se detiene y la notificación desaparece: el aviso queda '
      'guardado y vuelve a vigilar cuando abres la app otra vez, y en Android '
      'mientras tanto vigila el servidor. En iPhone el aviso solo suena con '
      'la app abierta.',
    ),
    LegalBlock.heading('Sin analítica, sin rastreo, sin publicidad'),
    LegalBlock.p(
      'La aplicación no incluye herramientas de analítica, de perfiles de '
      'uso ni de publicidad, y no vende ni cede datos a terceros.',
    ),
    LegalBlock.heading('Lo que se queda guardado en tu teléfono'),
    LegalBlock.p(
      'Algunas cosas sí se guardan dentro del teléfono, en el espacio privado '
      'de la app. Salvo el aviso armado en Android que se cuenta arriba, '
      'ninguna se manda a un servidor:',
    ),
    LegalBlock.bullet(
      'El punto de espera que hayas marcado a mano, para no tener que '
      'volver a marcarlo. Lo quitas con «Quitar», en el mismo mapa.',
    ),
    LegalBlock.bullet(
      'Tus avisos. Por cada bus al que le activaste uno: el bus, la ruta, '
      'cuándo lo activaste, cuándo sonó y, si lo activaste sobre un punto '
      'marcado a mano, ese punto. Es lo que deja que un aviso siga armado '
      'cuando vuelves a abrir la app. Se guardan los 50 más recientes de los '
      'últimos 30 días; los que todavía no han sonado se quedan hasta que '
      'suenen o los quites. Los borras todos desde Avisos.',
    ),
    LegalBlock.bullet(
      'Lo que ya aprendiste: si ya viste la bienvenida y la guía del mapa, '
      'y si ya se te pidió el permiso de ubicación.',
    ),
    LegalBlock.bullet(
      'Que aceptaste esto, con la versión del texto que aceptaste. Es lo '
      'que evita que la app te lo vuelva a preguntar cada vez, y lo que '
      'hace que te lo pregunte otra vez el día que cambie de fondo.',
    ),
    LegalBlock.p(
      'La ruta y la empresa que tienes abiertas en el mapa no se guardan: '
      'se eligen otra vez cada vez que abres la app. Tu posición del GPS '
      'tampoco se guarda, ni siquiera en el teléfono.',
    ),
    LegalBlock.p(
      'En Android nada de esto entra en la copia de seguridad de tu cuenta '
      'de Google. En iPhone forma parte de la copia del propio teléfono, si '
      'la tienes activada, como los datos de cualquier otra app. '
      'Desinstalar la app lo borra todo.',
    ),
    LegalBlock.heading('Lo que sí viaja: la posición del bus'),
    LegalBlock.p(
      'El que manda datos es el GPS del bus, no una persona. Es un equipo '
      'que va instalado en el vehículo y que, mientras el bus está en su '
      'ruta, publica la posición, el rumbo y la velocidad. Eso es un '
      'vehículo de servicio público en su recorrido, y es lo que hace '
      'posible que tú lo veas en el mapa.',
    ),
    LegalBlock.heading('Con quién se apoya la app'),
    LegalBlock.bullet(
      'OpenStreetMap y CARTO — las imágenes del mapa. Se descargan como '
      'cualquier imagen de una página; no llevan quién eres.',
    ),
    LegalBlock.bullet(
      'Servidores propios — las posiciones de los buses pasan por '
      'infraestructura nuestra, no por un servicio ajeno.',
    ),
    LegalBlock.bullet(
      'Firebase Cloud Messaging, de Google — solo en Android y solo para un '
      'aviso armado con la app cerrada: entrega la notificación. Lleva el '
      'bus, la ruta y la distancia, no tu ubicación.',
    ),
    LegalBlock.heading('Si usaste una versión anterior'),
    LegalBlock.p(
      'Las primeras versiones de prueba pedían entrar con un correo o con '
      'Google; la de hoy ya no. Si creaste una cuenta entonces, en ella '
      'quedaron dos datos, tu correo y el nombre que se mostraba, guardados '
      'en Firebase Authentication, de Google. De esa cuenta no hay nada más '
      'en nuestros servidores. Escríbenos por WhatsApp al 300 443 8626 y la '
      'borramos.',
    ),
    // Ley 1581 de 2012 y Decreto 1377 de 2013: quién responde, cómo se le
    // escribe y qué puede pedir el titular. Mismo texto que
    // `privacidad.html#responsable` y `#derechos` en la web. Sin cédula a
    // propósito: la ley pide identificar al responsable, no publicarla.
    // No sube `kLegalVersion`: informa, no cambia qué se recoge.
    LegalBlock.heading('Quién responde por tus datos'),
    LegalBlock.p(
      'El responsable es Diego Alejandro Angarita Silvera, en Barranquilla, '
      'Colombia. Correo diegoangarita930@gmail.com, WhatsApp 300 443 8626.',
    ),
    LegalBlock.heading('Tus derechos'),
    LegalBlock.p(
      'Por la Ley 1581 de 2012 puedes saber qué datos tuyos tenemos y para '
      'qué los usamos, pedir que los corrijamos o los borremos y retirar el '
      'permiso que nos diste. Pídelo por correo o por WhatsApp: una consulta '
      'la respondemos en máximo 10 días hábiles y un reclamo en máximo 15. '
      'Si después de reclamarnos no quedas conforme, puedes acudir a la '
      'Superintendencia de Industria y Comercio.',
    ),
    LegalBlock.heading('Cambios'),
    LegalBlock.p(
      'Si algo de esto cambia, cambia también este texto y su fecha, y la '
      'app te lo vuelve a mostrar. Ya Viene está en pruebas y todavía '
      'crece; lo que no va a cambiar es la parte de arriba: tu ubicación solo '
      'sale del teléfono para el aviso de Android, redondeada y por unas '
      'horas.',
    ),
  ],
);

const LegalDoc legalTerminos = LegalDoc(
  id: 'terminos',
  title: 'Términos de uso',
  updated: '15 de septiembre de 2026',
  blocks: [
    LegalBlock.p(
      'Ya Viene es un servicio en pruebas. Estas son las reglas del trato, '
      'en el menor número de palabras posible.',
    ),
    LegalBlock.heading('Qué es esto'),
    LegalBlock.p(
      'Ya Viene muestra dónde van los buses de las rutas conectadas y avisa '
      'cuando uno se acerca a donde esperas. Hoy funciona con seis rutas de '
      'Sobusa, en Barranquilla, en fase de piloto. Usarla como pasajero no '
      'cuesta nada.',
    ),
    LegalBlock.heading('Lo que sí prometemos y lo que no'),
    LegalBlock.p(
      'Lo que ves en el mapa es la posición que está publicando el GPS del '
      'bus en ese momento. Si el bus sale de servicio, se queda sin señal o '
      'su empresa lo apaga, ese bus deja de verse. Que un bus no aparezca '
      'no quiere decir que no exista.',
    ),
    LegalBlock.p(
      'Por eso Ya Viene no es un horario ni una garantía de llegada, y no '
      'nos hacemos responsables de que pierdas un bus, una cita o una '
      'clase. Es una ayuda para decidir mejor, no una promesa de la empresa '
      'de transporte.',
    ),
    LegalBlock.heading('Uso correcto'),
    LegalBlock.bullet('No suplantes a una empresa de transporte.'),
    LegalBlock.bullet(
      'No publiques posiciones falsas ni intentes alterar las que se '
      'muestran.',
    ),
    LegalBlock.bullet(
      'No uses la app para seguir a una persona. Lo que se ve son '
      'vehículos de servicio público en su recorrido.',
    ),
    LegalBlock.bullet(
      'Si conduces, no manipules el teléfono con el bus en marcha.',
    ),
    LegalBlock.heading('Para las empresas de transporte'),
    LegalBlock.p(
      'Conectar una flota se acuerda aparte, empresa por empresa. Lo que el '
      'GPS del vehículo publica es la posición, el rumbo y la velocidad del '
      'bus mientras está en su ruta.',
    ),
    LegalBlock.heading('Cambios y cierre'),
    LegalBlock.p(
      'Al ser un piloto, el servicio puede cambiar, pausarse o dejar de '
      'estar disponible. Si esto pasa lo diremos aquí y por los canales de '
      'contacto. Cualquier cambio en estos términos queda escrito aquí con '
      'su fecha.',
    ),
    LegalBlock.heading('Contacto'),
    LegalBlock.p(
      'WhatsApp 300 443 8626. Es el mismo número para pasajeros, empresas y '
      'autoridades.',
    ),
  ],
);

/// Los dos, en el orden en que se nombran en la bienvenida y en el menú.
const List<LegalDoc> legalDocs = [legalPrivacidad, legalTerminos];

/// El documento que pide un camino como `/legal/privacidad`. Devuelve
/// `null` si no es ninguno de los dos, y entonces el router enseña la
/// pantalla de ruta no encontrada en lugar de una en blanco.
LegalDoc? legalDocById(String? id) {
  for (final doc in legalDocs) {
    if (doc.id == id) return doc;
  }
  return null;
}
