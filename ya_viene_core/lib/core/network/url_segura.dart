/// Si una dirección del backend no deja salir nada en claro a la red.
///
/// `https` siempre vale. `http` solo contra la propia máquina, donde el
/// tráfico no llega a salir; por eso el nombre se compara entero
/// («mi.localhost» o «evillocalhost» no son esta máquina). Lo usan las dos
/// apps: por el panel viajan la clave y el token de la flota, y por el
/// pasajero el token de los avisos y el punto donde espera.
bool esUrlSegura(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'https') return true;
  return uri.scheme == 'http' &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1');
}
