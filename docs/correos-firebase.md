# Los correos que manda Firebase

Firebase arma estos correos en su servidor, no en la app. Por eso no viven
en el código: se escriben a mano en **Firebase Console → Authentication →
Templates**, con el lapicito de cada plantilla. Quedan aquí para que no se
pierdan si alguien rehace el proyecto, y para que el texto se revise como se
revisa cualquier otro texto que ve el usuario.

Lo único que sí está en el código es el idioma: `_auth.setLanguageCode('es')`
en [`auth_provider.dart`](../app_pasajero/lib/core/providers/auth_provider.dart).
Sin esa línea los correos salen en inglés aunque la app entera esté en
español.

## Lo que no se puede

El editor de Firebase no acepta diseño. Se come el CSS, así que no hay logo,
ni colores, ni maquetación: solo HTML básico —párrafos, negritas y enlaces—
sobre fondo blanco. Un correo maquetado exige dominio propio y un proveedor
de correo aparte, y eso es otra conversación.

Mientras no haya dominio, el remitente sigue siendo
`noreply@<proyecto>.firebaseapp.com`. Lo que sí se cambió es el nombre
visible, que ahora dice **Ya Viene** en vez del número del proyecto
(Console → Configuración del proyecto → General → Nombre visible público).

## El tono

De **tú**, corto y sin almidón, igual que la app: «Con tu correo y una
contraseña», «te avisamos antes de que llegue el tuyo». Español neutro
limpio con un solo giro costeño al final. Más sabor que ese empieza a sonar
a disfraz y no a marca.

Ninguna de las dos plantillas abre con el nombre. `%DISPLAY_NAME%` viene
vacío en las cuentas hechas solo con correo, y «Hola, :» se ve peor que
«Hola:».

## Restablecer contraseña

La manda `sendPasswordResetEmail` desde el «¿Olvidaste tu contraseña?» de la
pantalla de entrada.

**Asunto**

```
Tu enlace para cambiar la contraseña de Ya Viene
```

**Mensaje**

```html
<p>Hola:</p>

<p>Nos pediste cambiar la contraseña de tu cuenta de Ya Viene, la del correo <strong>%EMAIL%</strong>.</p>

<p>Si fuiste tú, entra aquí y elige una nueva:</p>

<p><a href="%LINK%">Cambiar mi contraseña</a></p>

<p>El enlace vence en una hora. Si no fuiste tú, no tienes que hacer nada: tu contraseña queda igual y nadie más puede entrar con ella.</p>

<p>Cualquier cosa, aquí estamos.</p>

<p>El equipo de Ya Viene<br>Barranquilla</p>
```

La hora que dice el texto es el valor por defecto de Firebase para los
enlaces de restablecimiento. Si algún día se cambia, hay que cambiar también
esa línea: un correo que promete una hora y vence en diez minutos es peor
que uno que no promete nada.

## Verificar el correo

**Hoy esta plantilla no se manda nunca.** La app crea la cuenta con
`createUserWithEmailAndPassword` y no llama a `sendEmailVerification()`, así
que el texto queda escrito y esperando. Queda anotado aquí para que quien lo
conecte no tenga que inventarse las palabras, y para que nadie crea que el
correo se está enviando cuando no.

**Asunto**

```
Confirma tu correo para empezar a usar Ya Viene
```

**Mensaje**

```html
<p>Hola:</p>

<p>Ya casi. Solo falta confirmar que este correo es tuyo para terminar de crear tu cuenta de Ya Viene.</p>

<p><a href="%LINK%">Confirmar mi correo</a></p>

<p>Con eso ya puedes elegir tu ruta y pedir que te avisemos antes de que llegue tu bus.</p>

<p>Si tú no creaste esta cuenta, ignora este mensaje y no pasa nada.</p>

<p>Cualquier cosa, aquí estamos.</p>

<p>El equipo de Ya Viene<br>Barranquilla</p>
```

A diferencia del de contraseña, este no promete cuánto dura el enlace. No
hace falta y así no hay una fecha que se pueda quedar mentirosa.
