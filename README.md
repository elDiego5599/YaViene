YA VIENE - Sistema de Monitoreo de Transporte Público en Tiempo Real

1. Descripción del Problema

El sistema de transporte público colectivo en ciudades intermedias como
Barranquilla presenta una deficiencia estructural en la comunicación de
información dinámica al usuario. Actualmente, los ciudadanos carecen de
visibilidad sobre la ubicación exacta de las unidades y los tiempos estimados de
llegada (ETA) a los puntos de parada.

Esta carencia de datos genera las siguientes consecuencias:

  - Incertidumbre operativa: Tiempos de espera improductivos que oscilan
    entre 30 y 90 minutos diarios por usuario.
  - Impacto socioeconómico: Degradación de la calidad de vida y pérdida de
    productividad individual.
  - Seguridad y Bienestar: Exposición prolongada en vía pública bajo condiciones
    climáticas adversas y riesgos de seguridad urbana.
  - Ineficiencia del sector: Falta de herramientas tecnológicas accesibles para
    que las pequeñas y medianas empresas operadoras optimicen sus flotas.

2. Solución Propuesta

YA VIENE es una plataforma tecnológica diseñada para cerrar la brecha de
información entre el conductor y el pasajero mediante un modelo de economía
colaborativa y rastreo basado en dispositivos móviles existentes (BYOD - Bring
Your Own Device).

La solución se articula a través de una aplicación móvil única con dos perfiles
diferenciados:

2.1. Rol del Conductor (Transmisor)

El dispositivo móvil del conductor actúa como nodo emisor de coordenadas
geográficas. Mediante una interfaz simplificada de bajo consumo energético, la
aplicación captura y transmite la posición GPS, velocidad y sentido de
desplazamiento hacia un servidor centralizado con una frecuencia de
actualización de 8 segundos.

2.2. Rol del Pasajero (Receptor)

El usuario final visualiza en un mapa interactivo la posición de los buses en
tiempo real. El sistema procesa la información geoespacial para calcular tiempos
de llegada basados en tráfico histórico y actual, permitiendo configurar alertas
de proximidad mediante notificaciones push.

3. Stack Tecnológico

La arquitectura está diseñada para garantizar baja latencia, alta disponibilidad
y escalabilidad horizontal.

3.1. Frontend (Mobile)

  - Framework: Flutter (Dart). Permite el despliegue multiplataforma
    (Android/iOS) con rendimiento nativo y gestión eficiente de renderizado de
    mapas.
  - Map Engine: Mapbox SDK. Seleccionado por su alta capacidad de
    personalización y optimización en el consumo de recursos frente a
    alternativas tradicionales.

3.2. Backend (Lógica de Negocio)

  - Entorno: Node.js. Implementado bajo una arquitectura de microservicios para
    separar la ingesta de datos de la consulta de API.
  - Comunicación en Tiempo Real:
      - MQTT: Protocolo ligero de mensajería para la transmisión de datos GPS
        desde el conductor, minimizando el consumo de datos móviles y batería.
      - WebSockets (Socket.io): Para el envío de actualizaciones en tiempo real
        hacia la aplicación del pasajero.

3.3. Gestión de Datos

  - Base de Datos Principal: PostgreSQL con extensión PostGIS. Necesaria para el
    almacenamiento y ejecución de consultas geoespaciales complejas.
  - Memoria Intermedia (Cache): Redis. Utilizada para almacenar las últimas
    posiciones conocidas de los buses activos, permitiendo respuestas de lectura
    con latencia inferior a 10ms.

3.4. Infraestructura y Cloud

  - Proveedor: AWS (Amazon Web Services).
  - Servicios Críticos:
      - AWS IoT Core: Para gestionar el broker MQTT y la conexión segura de
        miles de dispositivos simultáneos.
      - Elastic Container Service (ECS): Para la orquestación de los
        contenedores de la aplicación.

4. Estrategia de Implementación

El proyecto inicia bajo el "Plan A", utilizando el hardware existente de los
conductores. Este enfoque permite la validación inmediata del modelo de negocio
y la recopilación de datos de campo necesarios para futuras fases de
escalamiento mediante hardware IoT dedicado.
