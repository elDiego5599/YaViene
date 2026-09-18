/// Qué versión de la app está instalada.
///
/// Escrita a mano y no leída del paquete: `package_info_plus` es un plugin
/// con código nativo en las dos plataformas para devolver una cadena que ya
/// está en el `pubspec.yaml`, y esta app no tiene ninguna otra razón para
/// llevarlo. Lo que evita que la constante se quede vieja es una prueba
/// (`test/legal_test.dart`) que compara estas dos líneas con la del pubspec
/// y falla si alguien sube la versión sin pasar por aquí.
library;

/// El número que se le dice al usuario en «Acerca de».
const String kAppVersion = '1.0.0';

/// La compilación: sube sola en cada entrega a la tienda, no se enseña.
const int kAppBuild = 1;
