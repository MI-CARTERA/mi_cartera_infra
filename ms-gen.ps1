param(
  [Parameter(Mandatory=$true)][string]$Name,
  [Parameter(Mandatory=$true)][string]$GroupId,
  [Parameter(Mandatory=$false)][string]$ArtifactId = "",
  [Parameter(Mandatory=$false)][ValidateSet("postgres","mysql","mongo")][string]$Bd = "postgres",
  [Parameter(Mandatory=$false)][ValidateSet("maven","gradle")][string]$Build = "maven",
  [Parameter(Mandatory=$false)][string]$BootVersion = "3.5.0",
  [Parameter(Mandatory=$false)][string]$JavaVersion = "21",
  [Parameter(Mandatory=$false)][string]$OutputDir = ".",
  [Parameter(Mandatory=$false)][switch]$UseOutputDirAsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Ensure-Dir($p) {
  if (!(Test-Path $p)) {
    New-Item -ItemType Directory -Path $p | Out-Null
  }
}

function Write-Utf8NoBomFile([string]$Path, [string]$Content) {
  $dir = Split-Path -Parent $Path
  if ($dir -and !(Test-Path $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Append-Utf8NoBomFile([string]$Path, [string]$Content) {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

  if (Test-Path $Path) {
    $existing = [System.IO.File]::ReadAllText($Path)
    [System.IO.File]::WriteAllText($Path, ($existing + $Content), $utf8NoBom)
  } else {
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
  }
}

function Sanitize-Artifact([string]$artifactIdParam, [string]$nameParam) {
  if ($artifactIdParam -and $artifactIdParam.Trim().Length -gt 0) {
    return $artifactIdParam.Trim().ToLower()
  }
  if ($nameParam -and $nameParam.Trim().Length -gt 0) {
    return $nameParam.Trim().ToLower()
  }
  throw "Name y ArtifactId están vacíos. No se puede generar el microservicio."
}

function Ensure-MavenDependency([string]$PomPath, [string]$GroupId, [string]$ArtifactId, [string]$Scope = "") {
  if (!(Test-Path $PomPath)) {
    throw "No existe pom.xml en: $PomPath"
  }

  [xml]$pom = Get-Content $PomPath -Raw

  if (-not $pom.project.dependencies) {
    $dependenciesNode = $pom.CreateElement("dependencies", $pom.project.NamespaceURI)
    [void]$pom.project.AppendChild($dependenciesNode)
  }

  $alreadyExists = $false
  foreach ($dep in $pom.project.dependencies.dependency) {
    if ($dep.groupId -eq $GroupId -and $dep.artifactId -eq $ArtifactId) {
      $alreadyExists = $true
      break
    }
  }

  if (-not $alreadyExists) {
    $depNode = $pom.CreateElement("dependency", $pom.project.NamespaceURI)

    $groupNode = $pom.CreateElement("groupId", $pom.project.NamespaceURI)
    $groupNode.InnerText = $GroupId
    [void]$depNode.AppendChild($groupNode)

    $artifactNode = $pom.CreateElement("artifactId", $pom.project.NamespaceURI)
    $artifactNode.InnerText = $ArtifactId
    [void]$depNode.AppendChild($artifactNode)

    if ($Scope -and $Scope.Trim().Length -gt 0) {
      $scopeNode = $pom.CreateElement("scope", $pom.project.NamespaceURI)
      $scopeNode.InnerText = $Scope
      [void]$depNode.AppendChild($scopeNode)
    }

    [void]$pom.project.dependencies.AppendChild($depNode)
  }

  $settings = New-Object System.Xml.XmlWriterSettings
  $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
  $settings.Indent = $true
  $settings.OmitXmlDeclaration = $false

  $writer = [System.Xml.XmlWriter]::Create($PomPath, $settings)
  $pom.Save($writer)
  $writer.Close()
}

${Artifact} = Sanitize-Artifact $ArtifactId $Name

if ([string]::IsNullOrWhiteSpace(${Artifact})) {
  throw "Artifact quedó vacío. Revisá parámetros -Name/-ArtifactId."
}

$Package = "$GroupId.$(($Name).ToLower())".Replace("_","")

# Dependencias solicitadas a Spring Initializr
$deps = @("web","validation","actuator","lombok","amqp","data-redis")

if ($Bd -eq "mysql") {
  $deps += @("data-jpa","mysql")
}
elseif ($Bd -eq "postgres") {
  $deps += @("data-jpa","postgresql")
}
elseif ($Bd -eq "mongo") {
  $deps += @("data-mongodb")
}

$baseUri = "https://start.spring.io/starter.zip"
$params = @{
  type         = if($Build -eq "maven"){"maven-project"} else {"gradle-project"}
  language     = "java"
  bootVersion  = $BootVersion
  baseDir      = ${Artifact}
  groupId      = $GroupId
  artifactId   = ${Artifact}
  name         = ${Artifact}
  packageName  = $Package
  javaVersion  = $JavaVersion
  dependencies = ($deps -join ",")
}

$query = ($params.GetEnumerator() | ForEach-Object {
  "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString([string]$_.Value))"
}) -join "&"

$zipPath = Join-Path $env:TEMP "${Artifact}.zip"

if (!(Test-Path $OutputDir)) {
  throw "OutputDir no existe: $OutputDir"
}

$resolvedOut = (Resolve-Path -Path $OutputDir).Path

if ($UseOutputDirAsRoot) {
  $outPath = $resolvedOut
}
elseif ((Split-Path $resolvedOut -Leaf).ToLower() -eq ${Artifact}.ToLower()) {
  $outPath = $resolvedOut
}
else {
  $outPath = Join-Path $resolvedOut ${Artifact}
}

Write-Host "==> Generando microservicio: ${Artifact} (db=$Bd, build=$Build) en $outPath"

Invoke-WebRequest -Uri "${baseUri}?$query" -OutFile $zipPath | Out-Null

Ensure-Dir $outPath

$tmpDir = Join-Path $env:TEMP ("springinit_" + [Guid]::NewGuid().ToString("N"))
Ensure-Dir $tmpDir

Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force
Remove-Item $zipPath -Force

$root = Join-Path $tmpDir ${Artifact}

if (Test-Path $root) {
  Copy-Item -Path (Join-Path $root '*') -Destination $outPath -Recurse -Force
} else {
  Copy-Item -Path (Join-Path $tmpDir '*') -Destination $outPath -Recurse -Force
}

Remove-Item $tmpDir -Recurse -Force

# Asegurar driver en pom.xml (por si Initializr cambia o falla)
if ($Build -eq "maven") {
  $pomPath = Join-Path $outPath "pom.xml"

  if ($Bd -eq "postgres") {
    Ensure-MavenDependency -PomPath $pomPath -GroupId "org.postgresql" -ArtifactId "postgresql" -Scope "runtime"
  }
  elseif ($Bd -eq "mysql") {
    Ensure-MavenDependency -PomPath $pomPath -GroupId "com.mysql" -ArtifactId "mysql-connector-j" -Scope "runtime"
  }
}

$srcMain = Join-Path $outPath "src\main\java\$($Package.Replace('.','\'))"
$srcRes  = Join-Path $outPath "src\main\resources"

Ensure-Dir (Join-Path $srcMain "common")
Ensure-Dir (Join-Path $srcMain "config")
Ensure-Dir (Join-Path $srcMain "common\events")
Ensure-Dir (Join-Path $srcMain "common\events\dto")

# application.yml
$appYml = Join-Path $srcRes "application.yml"

$appYmlContent = @"
server:
  port: 8080

spring:
  application:
    name: ${Artifact}

  profiles:
    active: `${SPRING_PROFILES_ACTIVE:default}
"@

if ($Bd -eq "mysql") {
  $appYmlContent += @"

  datasource:
    url: `${SPRING_DATASOURCE_URL:jdbc:mysql://localhost:3306/${Artifact}?useSSL=false&serverTimezone=UTC}
    username: `${SPRING_DATASOURCE_USERNAME}
    password: `${SPRING_DATASOURCE_PASSWORD}

  jpa:
    hibernate:
      ddl-auto: `${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    open-in-view: false

"@
}
elseif ($Bd -eq "postgres") {
  $appYmlContent += @"

  datasource:
    url: `${SPRING_DATASOURCE_URL:jdbc:postgresql://localhost:5432/${Artifact}}
    username: `${SPRING_DATASOURCE_USERNAME}
    password: `${SPRING_DATASOURCE_PASSWORD}

  jpa:
    hibernate:
      ddl-auto: `${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    open-in-view: false

"@
}
elseif ($Bd -eq "mongo") {
  $appYmlContent += @"

  data:
    mongodb:
      uri: `${SPRING_DATA_MONGODB_URI:mongodb://localhost:27017/${Artifact}}

"@
}

$appYmlContent += @"
  rabbitmq:
    host: `${SPRING_RABBITMQ_HOST:localhost}
    port: `${SPRING_RABBITMQ_PORT:5672}
    username: `${SPRING_RABBITMQ_USERNAME}
    password: `${SPRING_RABBITMQ_PASSWORD}

  data:
    redis:
      host: `${SPRING_DATA_REDIS_HOST}
      port: `${SPRING_DATA_REDIS_PORT}

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
"@

Write-Utf8NoBomFile -Path $appYml -Content $appYmlContent

# application-docker.yml
$appDockerYml = Join-Path $srcRes "application-docker.yml"

$appDockerYmlContent = @"
spring:
  rabbitmq:
    host: `${SPRING_RABBITMQ_HOST:rabbitmq}
    port: `${SPRING_RABBITMQ_PORT:5672}
    username: `${SPRING_RABBITMQ_USERNAME}
    password: `${SPRING_RABBITMQ_PASSWORD}

  data:
    redis:
      host: `${SPRING_DATA_REDIS_HOST:redis}
      port: `${SPRING_DATA_REDIS_PORT:6379}
"@

if ($Bd -eq "mysql") {
  $appDockerYmlContent = @"
spring:
  datasource:
    url: `${SPRING_DATASOURCE_URL:jdbc:mysql://db_${Artifact}:3306/${Artifact}?useSSL=false&serverTimezone=UTC}
    username: `${SPRING_DATASOURCE_USERNAME}
    password: `${SPRING_DATASOURCE_PASSWORD}

  jpa:
    hibernate:
      ddl-auto: `${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    open-in-view: false

  rabbitmq:
    host: `${SPRING_RABBITMQ_HOST:rabbitmq}
    port: `${SPRING_RABBITMQ_PORT:5672}
    username: `${SPRING_RABBITMQ_USERNAME}
    password: `${SPRING_RABBITMQ_PASSWORD}

  data:
    redis:
      host: `${SPRING_DATA_REDIS_HOST:redis}
      port: `${SPRING_DATA_REDIS_PORT:6379}
"@
}
elseif ($Bd -eq "postgres") {
  $appDockerYmlContent = @"
spring:
  datasource:
    url: `${SPRING_DATASOURCE_URL:jdbc:postgresql://postgres:5432/${Artifact}}
    username: `${SPRING_DATASOURCE_USERNAME}
    password: `${SPRING_DATASOURCE_PASSWORD}

  jpa:
    hibernate:
      ddl-auto: `${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    open-in-view: false

  rabbitmq:
    host: `${SPRING_RABBITMQ_HOST:rabbitmq}
    port: `${SPRING_RABBITMQ_PORT:5672}
    username: `${SPRING_RABBITMQ_USERNAME}
    password: `${SPRING_RABBITMQ_PASSWORD}

  data:
    redis:
      host: `${SPRING_DATA_REDIS_HOST:redis}
      port: `${SPRING_DATA_REDIS_PORT:6379}
"@
}
elseif ($Bd -eq "mongo") {
  $appDockerYmlContent = @"
spring:
  data:
    mongodb:
      uri: `${SPRING_DATA_MONGODB_URI:mongodb://mongo:27017/${Artifact}}
    redis:
      host: `${SPRING_DATA_REDIS_HOST:redis}
      port: `${SPRING_DATA_REDIS_PORT:6379}

  rabbitmq:
    host: `${SPRING_RABBITMQ_HOST:rabbitmq}
    port: `${SPRING_RABBITMQ_PORT:5672}
    username: `${SPRING_RABBITMQ_USERNAME}
    password: `${SPRING_RABBITMQ_PASSWORD}
"@
}

Write-Utf8NoBomFile -Path $appDockerYml -Content $appDockerYmlContent

# .env.example dentro del microservicio
$envExamplePath = Join-Path $outPath ".env.example"
$envExampleContent = @"
# Copiar este archivo como .env en la raíz del proyecto infra/compose, no necesariamente aquí.
# Este archivo es solo referencia de variables necesarias.

Variables de entorno here

"@
Write-Utf8NoBomFile -Path $envExamplePath -Content $envExampleContent

# .dockerignore
$dockerIgnore = Join-Path $outPath ".dockerignore"
$dockerIgnoreContent = @"
target
build
.gradle
.idea
.vscode
*.iml
.git
logs
.env
"@
Write-Utf8NoBomFile -Path $dockerIgnore -Content $dockerIgnoreContent

# Dockerfile
$dockerfilePath = Join-Path $outPath "Dockerfile"

if ($Build -eq "maven") {
  $dockerfileContent = @"
# ---- build stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY pom.xml ./
RUN mvn -B -DskipTests dependency:go-offline

COPY src ./src
RUN mvn -B -DskipTests package

# ---- runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC"
ENTRYPOINT ["sh","-c","java `$JAVA_OPTS -jar /app/app.jar"]
"@
}
else {
  $dockerfileContent = @"
# ---- build stage ----
FROM gradle:8.7-jdk21 AS build
WORKDIR /app

COPY build.gradle settings.gradle gradle.properties* ./
COPY gradle ./gradle
RUN gradle --no-daemon dependencies

COPY src ./src
RUN gradle --no-daemon bootJar -x test

# ---- runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8080
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC"
ENTRYPOINT ["sh","-c","java `$JAVA_OPTS -jar /app/app.jar"]
"@
}

Write-Utf8NoBomFile -Path $dockerfilePath -Content $dockerfileContent

# docker-compose.example.yml de referencia para el infra repo
$composeExamplePath = Join-Path $outPath "docker-compose.example.yml"

if ($Bd -eq "postgres") {
  $composeExampleContent = @"
services:
  db_${Artifact}:
    image: postgres:16
    environment:
      POSTGRES_DB: `${POSTGRES_DB}
      POSTGRES_USER: `${POSTGRES_USER}
      POSTGRES_PASSWORD: `${POSTGRES_PASSWORD}
    ports:
      - "54${JavaVersion}:5432"

  ${Artifact}:
    build: .
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:postgresql://db_${Artifact}:5432/`${POSTGRES_DB}
      SPRING_DATASOURCE_USERNAME: `${POSTGRES_USER}
      SPRING_DATASOURCE_PASSWORD: `${POSTGRES_PASSWORD}
      SPRING_RABBITMQ_HOST: rabbitmq
      SPRING_RABBITMQ_PORT: 5672
      SPRING_RABBITMQ_USERNAME: `${RABBITMQ_USER}
      SPRING_RABBITMQ_PASSWORD: `${RABBITMQ_PASS}
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
    ports:
      - "81${JavaVersion}:8080"
"@
}
elseif ($Bd -eq "mysql") {
  $composeExampleContent = @"
services:
  db_${Artifact}:
    image: mysql:8.4
    environment:
      MYSQL_DATABASE: `${MYSQL_DATABASE}
      MYSQL_USER: `${MYSQL_USER}
      MYSQL_PASSWORD: `${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: `${MYSQL_ROOT_PASSWORD}
    ports:
      - "33${JavaVersion}:3306"

  ${Artifact}:
    build: .
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATASOURCE_URL: jdbc:mysql://db_${Artifact}:3306/`${MYSQL_DATABASE}?useSSL=false&serverTimezone=UTC
      SPRING_DATASOURCE_USERNAME: `${MYSQL_USER}
      SPRING_DATASOURCE_PASSWORD: `${MYSQL_PASSWORD}
      SPRING_RABBITMQ_HOST: rabbitmq
      SPRING_RABBITMQ_PORT: 5672
      SPRING_RABBITMQ_USERNAME: `${RABBITMQ_USER}
      SPRING_RABBITMQ_PASSWORD: `${RABBITMQ_PASS}
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
    ports:
      - "81${JavaVersion}:8080"
"@
}
else {
  $composeExampleContent = @"
services:
  db_${Artifact}:
    image: mongo:7
    environment:
      MONGO_INITDB_DATABASE: `${MONGO_INITDB_DATABASE}
    ports:
      - "27${JavaVersion}:27017"

  ${Artifact}:
    build: .
    environment:
      SPRING_PROFILES_ACTIVE: docker
      SPRING_DATA_MONGODB_URI: mongodb://db_${Artifact}:27017/`${MONGO_INITDB_DATABASE}
      SPRING_RABBITMQ_HOST: rabbitmq
      SPRING_RABBITMQ_PORT: 5672
      SPRING_RABBITMQ_USERNAME: `${RABBITMQ_USER}
      SPRING_RABBITMQ_PASSWORD: `${RABBITMQ_PASS}
      SPRING_DATA_REDIS_HOST: redis
      SPRING_DATA_REDIS_PORT: 6379
    ports:
      - "81${JavaVersion}:8080"
"@
}

Write-Utf8NoBomFile -Path $composeExamplePath -Content $composeExampleContent

# Rabbit config
$rabbitConfigPath = Join-Path $srcMain "common\events\RabbitConfig.java"
$rabbitConfigContent = @"
package $Package.common.events;

import org.springframework.amqp.core.Binding;
import org.springframework.amqp.core.BindingBuilder;
import org.springframework.amqp.core.Queue;
import org.springframework.amqp.core.QueueBuilder;
import org.springframework.amqp.core.TopicExchange;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class RabbitConfig {

  public static final String EXCHANGE = "mi_cartera_events";
  public static final String QUEUE = "${Artifact}_queue";
  public static final String ROUTING_KEY_ALL = "#";

  @Bean
  public TopicExchange miCarteraExchange() {
    return new TopicExchange(EXCHANGE, true, false);
  }

  @Bean
  public Queue serviceQueue() {
    return QueueBuilder.durable(QUEUE).build();
  }

  @Bean
  public Binding bindAll(Queue serviceQueue, TopicExchange miCarteraExchange) {
    return BindingBuilder.bind(serviceQueue).to(miCarteraExchange).with(ROUTING_KEY_ALL);
  }
}
"@
Write-Utf8NoBomFile -Path $rabbitConfigPath -Content $rabbitConfigContent

$publisherPath = Join-Path $srcMain "common\events\DomainEventPublisher.java"
$publisherContent = @"
package $Package.common.events;

import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class DomainEventPublisher {

  private final RabbitTemplate rabbitTemplate;

  public void publish(String routingKey, Object payload) {
    rabbitTemplate.convertAndSend(RabbitConfig.EXCHANGE, routingKey, payload);
  }
}
"@
Write-Utf8NoBomFile -Path $publisherPath -Content $publisherContent

$listenerPath = Join-Path $srcMain "common\events\ExampleEventListener.java"
$listenerContent = @"
package $Package.common.events;

import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class ExampleEventListener {

  @RabbitListener(queues = RabbitConfig.QUEUE)
  public void onMessage(Object event) {
    log.info("Event recibido: {}", event);
  }
}
"@
Write-Utf8NoBomFile -Path $listenerPath -Content $listenerContent

Write-Host "✅ Archivos generados en UTF-8 sin BOM"
Write-Host "✅ pom.xml reforzado con driver DB runtime"
Write-Host "✅ application.yml preparado para leer variables inyectadas por Docker Compose"
Write-Host "✅ Se generó .env.example y docker-compose.example.yml de referencia"
Write-Host "✅ Listo. Abrí la carpeta: $outPath"
Write-Host "DONE! Next => run entity-gen.ps1 for CRUD generation."
