# Mi Cartera Infrastructure

Infrastructure repository for **Mi Cartera**, a microservices-based personal finance platform. This repository groups the backend services, API gateway, frontend, shared infrastructure, and local development orchestration needed to run the platform as a complete environment.

## Project Objective

Mi Cartera is designed to support core personal finance workflows such as user management, bank account management, transaction tracking, financial goals, file handling, notifications, and AI-assisted classification. The main goal of this repository is to provide a practical and extensible infrastructure baseline so the platform can be developed, tested, and evolved as a distributed system instead of a single monolith.

This repo focuses on:

- Running the platform locally with Docker Compose
- Isolating business capabilities into independent microservices
- Centralizing access through an API gateway
- Enabling asynchronous communication through RabbitMQ
- Supporting shared runtime concerns such as Redis, PostgreSQL, networking, and service discovery through Docker DNS
- Accelerating service creation through automation scripts such as [`ms-gen.ps1`](./ms-gen.ps1) and [`entity-gen.ps1`](./entity-gen.ps1)

## Repository Scope

The repository currently contains:

- `frontend`: web client
- `api_gateway`: single entry point for client requests
- `ms_users`: user management
- `ms_bank_accounts`: bank account domain
- `ms_files`: file metadata and file-related API flows
- `ms_transactions`: financial movements and transactions
- `ms_goals`: financial goals
- `ms_notifications_cartera`: notifications
- `ms_ai_classifier`: AI helper service for transaction or movement classification
- `postgres`: database initialization assets
- `docker-compose.yml`: local orchestration for the whole platform

The compose file also includes references to additional domain services such as `ms_cash`, `ms_expenses`, `ms_saves`, and `ms_investments`, which represent planned or parallel capabilities within the same architecture.

## Architecture Overview

The platform follows a **microservices architecture** with a clear separation between entry points, domain services, data stores, and messaging infrastructure.

```text
Frontend
  -> API Gateway
      -> Microservices
          -> PostgreSQL
          -> Redis
          -> RabbitMQ

Microservices
  <-> RabbitMQ events
  <-> Redis cache/runtime data
```

At a high level:

- The **frontend** communicates only with the **API gateway**
- The **API gateway** routes requests to the appropriate backend service
- Each **microservice** owns a specific business capability
- Most services persist data in **PostgreSQL**
- **Redis** is available for shared runtime concerns such as caching and fast access data
- **RabbitMQ** provides asynchronous communication and event distribution

## High-Level Components

### Frontend

The frontend is exposed on port `5173` in local development and uses the gateway as its API base URL.

### API Gateway

The API gateway is exposed on port `8080` and acts as the external HTTP entry point for the platform. It centralizes:

- Route mapping
- Service forwarding
- Cross-cutting concerns such as auth validation and request tracing flags

Routes are defined in [`api_gateway/src/main/resources/gateway-routes.json`](./api_gateway/src/main/resources/gateway-routes.json), where each route maps an external path like `/api/users/**` or `/api/transactions/**` to a Docker-resolvable backend alias such as `http://ms-users:8080`.

### Microservices

Each microservice is an independent Spring Boot application with its own container, internal alias, and domain boundary. The current service landscape includes:

- `ms_users`: user records and identity-oriented domain logic
- `ms_bank_accounts`: bank account representation inside the platform
- `ms_files`: file metadata and file-related operations
- `ms_transactions`: transaction CRUD and movement-oriented flows
- `ms_goals`: savings or financial goal tracking
- `ms_notifications_cartera`: notification management
- `ms_ai_classifier`: AI-powered classification support

### Data and Infrastructure Services

- `postgres`: primary relational database engine used by most services
- `redis`: shared Redis instance for runtime support
- `rabbitmq`: broker for asynchronous events, with the management UI exposed on port `15672`

## How the Internal Communication Works

The project uses two Docker networks:

- `public`: for components that must be reachable from outside Docker, mainly the frontend, gateway, and RabbitMQ management exposure
- `backend`: an internal bridge network for service-to-service communication

The `backend` network is marked as internal in Docker Compose, which helps keep internal traffic isolated from direct external access.

### Request Flow

1. A user interacts with the frontend.
2. The frontend sends HTTP requests to the API gateway.
3. The gateway matches the request path and forwards it to the correct microservice using the Docker network alias.
4. The microservice processes the request and, when needed, accesses PostgreSQL, Redis, or publishes events to RabbitMQ.
5. The response returns through the gateway to the frontend.

### Service Discovery in Docker

There is no separate service registry in this setup. Instead, Docker Compose provides built-in name resolution:

- `ms-users`
- `ms-bank-accounts`
- `ms-files`
- `ms-transactions`
- `ms-goals`
- `ms-notifications-cartera`

These aliases are used by the gateway route configuration so containers can communicate by name inside the Docker network.

### Synchronous vs Asynchronous Communication

The architecture supports both patterns:

- **Synchronous communication** happens through HTTP requests routed by the gateway
- **Asynchronous communication** happens through RabbitMQ, where services can publish and consume domain events

This combination makes the platform easier to evolve. CRUD and query flows can remain simple over HTTP, while cross-service reactions can be implemented through events when needed.

## Service Structure and Development Pattern

The generated Java services follow a layered package structure oriented to API readiness:

- `api`: controllers and request entry points
- `api/dto`: request and response payload models
- `application`: service layer and use-case logic
- `domain`: core entity models
- `infrastructure`: repositories and persistence adapters
- `common/events`: RabbitMQ configuration, listeners, and publishers

This keeps responsibilities separated and makes the services easier to extend with validations, business rules, integrations, and tests.

## Automation and Code Generation

Two PowerShell scripts help standardize service creation:

### `ms-gen.ps1`

Generates a new Spring Boot microservice skeleton with:

- base Spring dependencies
- Dockerfile
- environment-oriented configuration
- RabbitMQ support
- Redis support
- initial package structure

### `entity-gen.ps1`

Generates CRUD scaffolding inside an existing service, including:

- entity or document model
- DTOs
- repository
- service
- REST controller

This makes it much faster to create testable APIs while keeping the same architectural conventions across services.

## Local Development with Docker Compose

The full environment is orchestrated from [`docker-compose.yml`](./docker-compose.yml).

Main exposed ports:

- `5173`: frontend
- `8080`: API gateway
- `5432`: PostgreSQL
- `6379`: Redis
- `5672`: RabbitMQ broker
- `15672`: RabbitMQ management UI
- `8101` to `8111`: direct service ports for local debugging

Typical local workflow:

1. Configure required environment variables in the root `.env`
2. Build and start the stack with Docker Compose
3. Access the frontend through `http://localhost:5173`
4. Access backend APIs through `http://localhost:8080`
5. Use RabbitMQ management on `http://localhost:15672` if needed

## Configuration Model

The services rely on environment variables for runtime configuration. Common settings include:

- database URL, user, and password
- RabbitMQ host, port, user, and password
- Redis host and port
- JWT secret for gateway-level auth concerns
- external API secrets such as `OPENAI_API_KEY` for AI-specific services

This keeps the services portable between local development and future deployment environments.

## Current Design Direction

The project has been developed with a practical infrastructure-first approach:

- start from clear domain separation
- create an isolated service per business capability
- place a gateway in front of the backend
- provide local networking and shared infrastructure through Docker Compose
- add async messaging from the beginning to avoid tight coupling
- use generators to speed up consistent service creation

This makes the repository suitable for iterative growth: new services can be added without restructuring the whole platform, and existing services can evolve independently.

## Notes and Current Status

- The repository already contains the core infrastructure needed for local distributed development
- Several services are API-ready or scaffolded to become API-ready quickly
- Some services referenced in Docker Compose appear to be part of the planned domain map and may still need implementation in this repository
- The architecture is intentionally modular so authentication, authorization, event choreography, observability, and deployment automation can be expanded later

## Summary

Mi Cartera Infrastructure is the operational foundation of a modular personal finance platform. It combines Spring Boot microservices, an API gateway, Docker networking, PostgreSQL, Redis, RabbitMQ, and service generators into a development environment that is clear, extensible, and aligned with modern backend architecture practices.
