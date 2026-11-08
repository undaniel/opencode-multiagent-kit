# AGENTS.md — proyecto Java

## Stack

- Java 21 LTS salvo que el repo fije otra versión.
- Maven o Gradle; usa el wrapper (`./mvnw` o `./gradlew`) del repo.
- Sin dependencias nuevas sin justificar tamaño, mantenimiento y alternativa estándar.

## Comandos

```bash
./mvnw verify          # Maven
./gradlew build        # Gradle
./mvnw spotless:check  # si el repo usa Spotless
./gradlew spotlessCheck
```

## Definition of Done

1. El build y los tests pasan con el wrapper.
2. Formato/estilo pasan (Spotless, Checkstyle o el que use el repo).
3. Los tests cubren criterios de aceptación, incluidos errores.
4. No hay secretos ni `.env` en el diff.
5. Docs actualizadas si cambió CLI, API, config o env.
6. La app arranca y responde: `bash .opencode/smoke.sh` pasa.
7. Diff mínimo, sin refactors no pedidos.

## Convenciones

- Inyección por constructor; evita estado mutable estático.
- Excepciones con contexto; no captures `Exception` sin manejarla.
- `Optional` para retornos ausentes; no para campos.
- Timeouts explícitos en clientes HTTP; cierra recursos con try-with-resources.
- Tests con JUnit 5; integración con `@SpringBootTest`/Testcontainers si aplica.
- Logs con SLF4J; nunca `System.out` en producción.

## Seguridad

- Sin secretos en el repo; usa variables de entorno o el gestor del despliegue.
- Valida entrada externa; no confíes en headers, query ni cuerpos.
- Si haces peticiones salientes: allowlist de hosts y bloqueo de IPs privadas (SSRF).
- Deserialización segura; no uses `ObjectInputStream` con datos externos.
- Dependencias auditadas (OWASP Dependency-Check o `mvn dependency:tree` + revisión).
- Cabeceras de seguridad si sirves HTML.

## Flujo con agentes

- Cambio de ≤2 archivos y sin superficie sensible: `build`.
- Feature/refactor/ambiguo: `orchestrator` → plan → aprobación → slices.
- No commit ni push sin pedido explícito. Conventional Commits.
