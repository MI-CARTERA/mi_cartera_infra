param(
  [Parameter(Mandatory=$true)][string]$Name,            # ms_clientes
  [Parameter(Mandatory=$true)][string]$GroupId,         # com.tuorg
  [Parameter(Mandatory=$false)][string]$ArtifactId = "",# ms-clientes
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

function Ensure-Dir($p){
  if(!(Test-Path $p)){
    New-Item -ItemType Directory -Path $p | Out-Null
  }
}

function Sanitize-Artifact([string]$artifactIdParam, [string]$nameParam){
  if($artifactIdParam -and $artifactIdParam.Trim().Length -gt 0){
    return $artifactIdParam.Trim().ToLower()
  }
  if($nameParam -and $nameParam.Trim().Length -gt 0){
    return $nameParam.Trim().ToLower()
  }
  throw "Name y ArtifactId están vacíos. No se puede generar el microservicio."
}

$Artifact = Sanitize-Artifact $ArtifactId $Name

if([string]::IsNullOrWhiteSpace($Artifact)){
  throw "Artifact quedó vacío. Revisá parámetros -Name/-ArtifactId."
}

$Package = "$GroupId.$(($Name).ToLower())".Replace("_","")

# Dependencias base
$deps = @("web","validation","actuator","lombok","amqp","data-redis")
# llamadas inter-servicio por HTTP:
# $deps += @("cloud-feign")

if($Bd -eq "mysql"){
  $deps += @("data-jpa","mysql")
} elseif($Bd -eq "postgres"){
  $deps += @("data-jpa","postgresql")
} elseif($Bd -eq "mongo"){
  $deps += @("data-mongodb")
}

# Parámetros Spring Initializr
$baseUri = "https://start.spring.io/starter.zip"
$params = @{
  type         = if($Build -eq "maven"){"maven-project"} else {"gradle-project"}
  language     = "java"
  bootVersion  = $BootVersion
  baseDir      = $Artifact
  groupId      = $GroupId
  artifactId   = $Artifact
  name         = $Artifact
  packageName  = $Package
  javaVersion  = $JavaVersion
  dependencies = ($deps -join ",")
}

# Construir query string
$query = ($params.GetEnumerator() | ForEach-Object {
  "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString([string]$_.Value))"
}) -join "&"

# Paths
$zipPath = Join-Path $env:TEMP "$Artifact.zip"

if(!(Test-Path $OutputDir)){
  throw "OutputDir no existe: $OutputDir"
}

$resolvedOut = (Resolve-Path -Path $OutputDir).Path

if ($UseOutputDirAsRoot) {
  $outPath = $resolvedOut
}
elseif ((Split-Path $resolvedOut -Leaf).ToLower() -eq $Artifact.ToLower()) {
  $outPath = $resolvedOut
}
else {
  $outPath = Join-Path $resolvedOut $Artifact
}

Write-Host "==> Generando microservicio: $Artifact (db=$Bd, build=$Build) en $outPath"

# Descargar zip desde Spring Initializr
Invoke-WebRequest -Uri "${baseUri}?$query" -OutFile $zipPath | Out-Null

# Crear carpeta destino
Ensure-Dir $outPath

# Extraer en tmp
$tmpDir = Join-Path $env:TEMP ("springinit_" + [Guid]::NewGuid().ToString("N"))
Ensure-Dir $tmpDir

Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force
Remove-Item $zipPath -Force

$root = Join-Path $tmpDir $Artifact

if (Test-Path $root) {
  Copy-Item -Path (Join-Path $root '*') -Destination $outPath -Recurse -Force
} else {
  Copy-Item -Path (Join-Path $tmpDir '*') -Destination $outPath -Recurse -Force
}

Remove-Item $tmpDir -Recurse -Force

# Crear estructura base extra
$srcMain = Join-Path $outPath "src\main\java\$($Package.Replace('.','\'))"
$srcRes  = Join-Path $outPath "src\main\resources"

Ensure-Dir (Join-Path $srcMain "common")
Ensure-Dir (Join-Path $srcMain "config")
Ensure-Dir (Join-Path $srcMain "common\events")
Ensure-Dir (Join-Path $srcMain "common\events\dto")

# application.yml básico
$appYml = Join-Path $srcRes "application.yml"
if(!(Test-Path $appYml)){
@"
server:
  port: 8080

spring:
  application:
    name: $Artifact

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
"@ | Set-Content -Encoding UTF8 $appYml
}

# Config local DB
if($Bd -eq "mysql"){
  Add-Content -Encoding UTF8 $appYml @"

  datasource:
    url: jdbc:mysql://localhost:3306/${Artifact}?useSSL=false&serverTimezone=UTC
    username: root
    password: root
  jpa:
    hibernate:
      ddl-auto: update
    open-in-view: false
"@
}
elseif($Bd -eq "postgres"){
  Add-Content -Encoding UTF8 $appYml @"

  datasource:
    url: jdbc:postgresql://localhost:5432/${Artifact}
    username: postgres
    password: postgres
  jpa:
    hibernate:
      ddl-auto: update
    open-in-view: false
"@
}
elseif($Bd -eq "mongo"){
  Add-Content -Encoding UTF8 $appYml @"

  data:
    mongodb:
      uri: mongodb://localhost:27017/${Artifact}
"@
}

# application-docker.yml
$appDockerYml = Join-Path $srcRes "application-docker.yml"
if(!(Test-Path $appDockerYml)){
  if($Bd -eq "mysql"){
@"
spring:
  datasource:
    url: jdbc:mysql://db_${Artifact}:3306/${Artifact}?useSSL=false&serverTimezone=UTC
    username: ${Artifact}
    password: ${Artifact}
  jpa:
    hibernate:
      ddl-auto: update
    open-in-view: false

  rabbitmq:
    host: rabbitmq
    port: 5672
    username: user
    password: password

  data:
    redis:
      host: redis
      port: 6379
"@ | Set-Content -Encoding UTF8 $appDockerYml
  }
  elseif($Bd -eq "postgres"){
@"
spring:
  datasource:
    url: jdbc:postgresql://db_${Artifact}:5432/${Artifact}
    username: ${Artifact}
    password: ${Artifact}
  jpa:
    hibernate:
      ddl-auto: update
    open-in-view: false

  rabbitmq:
    host: rabbitmq
    port: 5672
    username: user
    password: password

  data:
    redis:
      host: redis
      port: 6379
"@ | Set-Content -Encoding UTF8 $appDockerYml
  }
  elseif($Bd -eq "mongo"){
@"
spring:
  data:
    mongodb:
      uri: mongodb://db_${Artifact}:27017/${Artifact}

  rabbitmq:
    host: rabbitmq
    port: 5672
    username: user
    password: password

  data:
    redis:
      host: redis
      port: 6379
"@ | Set-Content -Encoding UTF8 $appDockerYml
  }
}

# .dockerignore
$dockerIgnore = Join-Path $outPath ".dockerignore"
if(!(Test-Path $dockerIgnore)){
@"
target
build
.gradle
.idea
.vscode
*.iml
.git
logs
"@ | Set-Content -Encoding UTF8 $dockerIgnore
}

# Dockerfile
$dockerfilePath = Join-Path $outPath "Dockerfile"
if(!(Test-Path $dockerfilePath)){
  if($Build -eq "maven"){
@"
# ---- build stage ----
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app

COPY .mvn .mvn
COPY mvnw mvnw
COPY mvnw.cmd mvnw.cmd
COPY pom.xml ./
RUN chmod +x mvnw || true
RUN ./mvnw -q -DskipTests dependency:go-offline || mvn -q -DskipTests dependency:go-offline

COPY src ./src
RUN ./mvnw -q -DskipTests package || mvn -q -DskipTests package

# ---- runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar

EXPOSE 8080
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseG1GC"
ENTRYPOINT ["sh","-c","java `$JAVA_OPTS -jar /app/app.jar"]
"@ | Set-Content -Encoding UTF8 $dockerfilePath
  }
  else {
@"
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
"@ | Set-Content -Encoding UTF8 $dockerfilePath
  }
}

# Rabbit config
$rabbitConfigPath = Join-Path $srcMain "common\events\RabbitConfig.java"
if(!(Test-Path $rabbitConfigPath)){
@"
package $Package.common.events;

import org.springframework.amqp.core.*;
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
"@ | Set-Content -Encoding UTF8 $rabbitConfigPath
}

$publisherPath = Join-Path $srcMain "common\events\DomainEventPublisher.java"
if(!(Test-Path $publisherPath)){
@"
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
"@ | Set-Content -Encoding UTF8 $publisherPath
}

$listenerPath = Join-Path $srcMain "common\events\ExampleEventListener.java"
if(!(Test-Path $listenerPath)){
@"
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
"@ | Set-Content -Encoding UTF8 $listenerPath
}

Write-Host "✅ Docker ready: Dockerfile + .dockerignore + application-docker.yml + Rabbit templates"
Write-Host "✅ Listo. Abrí la carpeta: $outPath"
Write-Host "DONE!, Next =>: run entity-gen.ps1 file for generate CRUD."