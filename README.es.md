# Infraestructura de Mi Cartera

Repositorio de infraestructura para **Mi Cartera**, una plataforma de finanzas personales basada en microservicios. Este repositorio reúne los servicios backend, el API gateway, el frontend, la infraestructura compartida y la orquestación local necesaria para ejecutar la plataforma como un entorno completo.

## Objetivo del Proyecto

Mi Cartera está pensada para cubrir flujos centrales de finanzas personales, como gestión de usuarios, cuentas bancarias, movimientos, metas financieras, archivos, notificaciones y clasificación asistida por IA. El objetivo principal de este repositorio es ofrecer una base de infraestructura práctica y extensible para desarrollar, probar y evolucionar la plataforma como un sistema distribuido y no como un monolito.

Este repositorio se enfoca en:

- Ejecutar la plataforma localmente con Docker Compose
- Aislar capacidades de negocio en microservicios independientes
- Centralizar el acceso mediante un API gateway
- Habilitar comunicación asíncrona con RabbitMQ
- Cubrir preocupaciones compartidas de ejecución como Redis, PostgreSQL, red y resolución de nombres entre contenedores
- Acelerar la creación de servicios mediante scripts como [`ms-gen.ps1`](./ms-gen.ps1) y [`entity-gen.ps1`](./entity-gen.ps1)

## Alcance del Repositorio

Actualmente el repositorio contiene:

- `frontend`: cliente web
- `api_gateway`: punto único de entrada para las requests
- `ms_users`: gestión de usuarios
- `ms_bank_accounts`: dominio de cuentas bancarias
- `ms_files`: metadata de archivos y flujos relacionados
- `ms_transactions`: movimientos y transacciones financieras
- `ms_goals`: metas financieras
- `ms_notifications_cartera`: notificaciones
- `ms_ai_classifier`: servicio auxiliar de IA para clasificación de movimientos o transacciones
- `postgres`: assets de inicialización de base de datos
- `docker-compose.yml`: orquestación local de toda la plataforma

El archivo de Compose también incluye referencias a servicios adicionales como `ms_cash`, `ms_expenses`, `ms_saves` y `ms_investments`, que representan capacidades planificadas o paralelas dentro de la misma arquitectura.

## Visión General de la Arquitectura

La plataforma sigue una **arquitectura de microservicios** con una separación clara entre puntos de entrada, servicios de dominio, almacenamiento y mensajería.

```text
Frontend
  -> API Gateway
      -> Microservicios
          -> PostgreSQL
          -> Redis
          -> RabbitMQ

Microservicios
  <-> Eventos RabbitMQ
  <-> Cache o datos runtime en Redis
```

A nivel general:

- El **frontend** se comunica solo con el **API gateway**
- El **API gateway** enruta las requests hacia el servicio correspondiente
- Cada **microservicio** se encarga de una capacidad de negocio específica
- La mayoría de los servicios persisten datos en **PostgreSQL**
- **Redis** está disponible para necesidades compartidas de ejecución, como cache o acceso rápido a datos
- **RabbitMQ** provee comunicación asíncrona y distribución de eventos

## Componentes Principales

### Frontend

El frontend se expone en el puerto `5173` durante el desarrollo local y usa al gateway como base de acceso a la API.

### API Gateway

El API gateway se expone en el puerto `8080` y funciona como el punto de entrada HTTP externo de la plataforma. Centraliza:

- mapeo de rutas
- forwarding hacia servicios internos
- preocupaciones transversales como validación de auth y flags de trazabilidad

Las rutas están definidas en [`api_gateway/src/main/resources/gateway-routes.json`](./api_gateway/src/main/resources/gateway-routes.json), donde cada ruta conecta un path externo como `/api/users/**` o `/api/transactions/**` con un alias de backend resoluble por Docker, por ejemplo `http://ms-users:8080`.

### Microservicios

Cada microservicio es una aplicación Spring Boot independiente con su propio contenedor, alias interno y límite de dominio. El panorama actual incluye:

- `ms_users`: registros de usuarios y lógica orientada a identidad
- `ms_bank_accounts`: representación de cuentas bancarias dentro de la plataforma
- `ms_files`: metadata de archivos y operaciones relacionadas
- `ms_transactions`: CRUD de transacciones y flujos de movimientos
- `ms_goals`: seguimiento de metas financieras
- `ms_notifications_cartera`: gestión de notificaciones
- `ms_ai_classifier`: soporte de clasificación impulsado por IA

### Servicios de Datos e Infraestructura

- `postgres`: motor relacional principal usado por la mayoría de los servicios
- `redis`: instancia Redis compartida para soporte runtime
- `rabbitmq`: broker de eventos asíncronos, con panel de administración expuesto en el puerto `15672`

## Cómo Funciona la Comunicación Interna

El proyecto utiliza dos redes Docker:

- `public`: para componentes que deben ser accesibles desde fuera de Docker, principalmente frontend, gateway y la interfaz de administración de RabbitMQ
- `backend`: una red bridge interna para comunicación entre servicios

La red `backend` está marcada como interna en Docker Compose, lo que ayuda a mantener aislado el tráfico interno del acceso directo externo.

### Flujo de Requests

1. Un usuario interactúa con el frontend.
2. El frontend envía requests HTTP al API gateway.
3. El gateway identifica la ruta y la reenvía al microservicio correcto usando el alias de Docker.
4. El microservicio procesa la request y, cuando corresponde, accede a PostgreSQL, Redis o publica eventos en RabbitMQ.
5. La respuesta vuelve por el gateway hacia el frontend.

### Descubrimiento de Servicios en Docker

En esta solución no hay un registry separado. En su lugar, Docker Compose brinda resolución de nombres entre contenedores:

- `ms-users`
- `ms-bank-accounts`
- `ms-files`
- `ms-transactions`
- `ms-goals`
- `ms-notifications-cartera`

Estos aliases son usados por la configuración del gateway para que los contenedores se comuniquen por nombre dentro de la red Docker.

### Comunicación Sincrónica y Asincrónica

La arquitectura soporta ambos patrones:

- **Comunicación sincrónica** por HTTP, a través del gateway
- **Comunicación asincrónica** mediante RabbitMQ, donde los servicios pueden publicar y consumir eventos de dominio

Esta combinación facilita la evolución de la plataforma. Los flujos CRUD y de consulta pueden mantenerse simples sobre HTTP, mientras que las reacciones entre servicios pueden implementarse con eventos cuando sea necesario.

## Estructura de los Servicios y Patrón de Desarrollo

Los servicios Java generados siguen una estructura por capas orientada a dejar APIs listas para probar:

- `api`: controllers y puntos de entrada
- `api/dto`: modelos de request y response
- `application`: capa de servicios y lógica de casos de uso
- `domain`: modelos de entidad del núcleo del dominio
- `infrastructure`: repositorios y adaptadores de persistencia
- `common/events`: configuración de RabbitMQ, listeners y publishers

Esto mantiene las responsabilidades separadas y hace más fácil extender los servicios con validaciones, reglas de negocio, integraciones y tests.

## Automatización y Generación de Código

Dos scripts de PowerShell ayudan a estandarizar la creación de servicios:

### `ms-gen.ps1`

Genera el esqueleto de un nuevo microservicio Spring Boot con:

- dependencias base de Spring
- Dockerfile
- configuración orientada a ambientes
- soporte para RabbitMQ
- soporte para Redis
- estructura inicial de paquetes

### `entity-gen.ps1`

Genera el scaffolding CRUD dentro de un servicio existente, incluyendo:

- entidad o documento
- DTOs
- repositorio
- servicio
- controller REST

Esto acelera mucho la creación de APIs testeables manteniendo las mismas convenciones arquitectónicas entre servicios.

## Desarrollo Local con Docker Compose

Todo el entorno se orquesta desde [`docker-compose.yml`](./docker-compose.yml).

Puertos principales expuestos:

- `5173`: frontend
- `8080`: API gateway
- `5432`: PostgreSQL
- `6379`: Redis
- `5672`: broker RabbitMQ
- `15672`: interfaz de administración de RabbitMQ
- `8101` a `8111`: puertos directos de microservicios para debugging local

Flujo típico de trabajo local:

1. Configurar las variables requeridas en el `.env` raíz
2. Construir y levantar el stack con Docker Compose
3. Acceder al frontend en `http://localhost:5173`
4. Acceder a las APIs backend mediante `http://localhost:8080`
5. Usar RabbitMQ Management en `http://localhost:15672` si hace falta

## Modelo de Configuración

Los servicios dependen de variables de entorno para su configuración en runtime. Entre las más comunes están:

- URL, usuario y password de base de datos
- host, puerto, usuario y password de RabbitMQ
- host y puerto de Redis
- secreto JWT para preocupaciones de auth a nivel gateway
- secretos externos como `OPENAI_API_KEY` para servicios con IA

Esto mantiene a los servicios portables entre desarrollo local y futuros entornos de despliegue.

## Dirección Actual del Diseño

El proyecto fue desarrollado con un enfoque práctico, primero de infraestructura:

- arrancar desde una separación clara del dominio
- crear un servicio aislado por capacidad de negocio
- colocar un gateway delante del backend
- resolver red local e infraestructura compartida con Docker Compose
- incorporar mensajería asíncrona desde el inicio para evitar acoplamiento fuerte
- usar generadores para acelerar una creación consistente de servicios

Esto vuelve al repositorio adecuado para crecer de manera iterativa: se pueden agregar nuevos servicios sin reestructurar toda la plataforma, y los existentes pueden evolucionar de forma independiente.

## Notas y Estado Actual

- El repositorio ya contiene la infraestructura central necesaria para desarrollo distribuido local
- Varios servicios ya están listos para API o scaffolded para quedar listos rápidamente
- Algunos servicios referenciados en Docker Compose parecen formar parte del mapa de dominio planificado y todavía pueden requerir implementación dentro del repositorio
- La arquitectura es intencionalmente modular para ampliar más adelante auth, autorización, coreografía por eventos, observabilidad y automatización de despliegue

## Resumen

Mi Cartera Infrastructure es la base operativa de una plataforma modular de finanzas personales. Combina microservicios Spring Boot, API gateway, redes Docker, PostgreSQL, Redis, RabbitMQ y generadores de servicios en un entorno de desarrollo claro, extensible y alineado con prácticas modernas de arquitectura backend.
