# YA VIENE - Sistema de Monitoreo de Transporte Público en Tiempo Real

## 1. Descripción del Problema

El sistema de transporte público colectivo en ciudades como Barranquilla carece de mecanismos eficientes de información al usuario. La ausencia de datos sobre la ubicación de las unidades genera una cadena de ineficiencias:

* **Incertidumbre operativa:** El usuario promedio pierde entre 30 y 90 minutos diarios esperando unidades sin conocimiento de su proximidad.
* **Impacto en productividad:** La falta de previsibilidad afecta el cumplimiento de horarios laborales y académicos.
* **Riesgos de seguridad:** La permanencia prolongada e innecesaria en paradas de bus incrementa la exposición a factores de riesgo ambiental y social.

## 2. Solución Propuesta

YA VIENE propone una infraestructura digital basada en una aplicación móvil de doble propósito que utiliza el modelo BYOD (Bring Your Own Device) para capturar datos geográficos sin requerir inversión inicial en hardware por parte de las empresas transportadoras.

### 2.1. Funcionalidad del Sistema
* **Perfil Conductor:** La aplicación accede al módulo GPS del dispositivo móvil para transmitir coordenadas, velocidad y sentido de marcha mediante una conexión de bajo impacto en el plan de datos.
* **Perfil Pasajero:** Interfaz cartográfica que muestra el desplazamiento de las unidades en tiempo real y calcula tiempos estimados de llegada (ETA) basados en la posición actual del vehículo y el tráfico circundante.

## 3. Stack Tecnológico

El ecosistema técnico se fundamenta en tecnologías de alta concurrencia y procesamiento geoespacial.

### 3.1. Desarrollo Mobile (Frontend)
* **Framework:** Flutter (Dart). Implementación de una base de código único para despliegue en Android e iOS, garantizando rendimiento nativo y manejo fluido de capas cartográficas.
* **Motor de Mapas:** Mapbox SDK. Utilizado para la renderización de mapas vectoriales y cálculos de rutas.

### 3.2. Arquitectura Backend
* **Entorno de ejecución:** Node.js. Procesamiento asíncrono ideal para la gestión de múltiples conexiones simultáneas.
* **Protocolos de Comunicación:**
    * **MQTT:** Para la ingesta de datos GPS desde el móvil del conductor, optimizando el consumo de batería y la resiliencia ante redes móviles inestables.
    * **WebSockets:** Para la actualización en tiempo real de las posiciones en la interfaz del pasajero.

### 3.3. Persistencia y Gestión de Datos
* **Base de Datos Relacional:** PostgreSQL + PostGIS. Almacenamiento de rutas, paradas y ejecución de consultas de proximidad geográfica.
* **Caché de Alta Velocidad:** Redis. Almacenamiento en memoria de las últimas coordenadas conocidas para reducir la latencia de respuesta en las peticiones de los usuarios.

### 3.4. Infraestructura
* **Cloud Computing:** Amazon Web Services (AWS) o Google Cloud Platform (GCP).
* **Servicios:** Contenedores (Docker) y orquestación para escalabilidad horizontal según la demanda del servicio.

## 4. Estrategia de Trabajo

El desarrollo se ejecutará bajo la modalidad del "Plan A": validación de concepto y viabilidad técnica utilizando los sensores de los dispositivos móviles de los conductores. Este enfoque permite la iteración rápida del software y la acumulación de datos de tráfico antes de una posible transición a hardware IoT dedicado.
