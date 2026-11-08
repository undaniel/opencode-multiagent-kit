<!-- opencode-multiagent-kit:start -->
## Kit multiagente (gestionado)

- Responde al usuario en su idioma. El pensamiento interno y la delegación, en inglés salvo indicación contraria.
- OpenCode V2: el tool de delegación es `subagent` (los prompts antiguos lo llaman `Task`); los permisos siguen en `permission.task`.
- No hagas `git commit` ni `git push` sin pedido explícito del usuario.
- No leas, imprimas ni pegues secretos (`.env*`, claves, tokens, `.ssh`) en prompts de subagentes.
- Comandos destructivos (`rm`, `sudo`, git destructivo) y llamadas de red requieren confirmación.
- Verifica con el comando más estrecho que pruebe el cambio y reporta la evidencia; nunca declares éxito sin salida de comandos.
- Si un fix excede el plan aprobado o toca rutas prohibidas, detente y vuelve a planificar.
- Los revisores no escriben código ni historia git; solo leen y emiten veredictos.
<!-- opencode-multiagent-kit:end -->
