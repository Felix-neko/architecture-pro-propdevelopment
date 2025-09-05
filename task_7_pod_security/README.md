# Задание 7. Аудит и обеспечение соответствия политике безопасности контейнеров

## Как протестироваться?
Стартуем minikube:
```bash
bash setup_minikube.sh
```

И создадим 3 пространства: 
- `insecure` (без контроля привилегий), 
- `pod-security` (контроль привилегий через штатный куберовский `PodSecurity`),
- `opa-gatekeeper-controlled` (контроль привилегий через великий и ужасный OPA Gatekeeper).

```bash
bash create_namespaces.sh
```


После того мы включим для `pod-security` и `opa-gatekeeper-controlled` контроль привилегий:

```bash
bash install_pod_security.sh  # Дополнительных спецификаций не надо, настройки PodSecurity выставляются прямо в скрипте
bash install_opa_gatekeeper.sh
```

И запустим проверочный скрипт, который попытается создать одинаковый набор подов (1 без привилегий и 3 с разными привилегиями) во всех 3 пространствах:

```bash
bash create_insecure_pods.sh
```

Вывод должен быть таким:

```
=== Insecure ===
pod/nothing-special-nginx created
pod/privileged-nginx created
pod/hostpath-nginx created
pod/root-user-nginx created
=== PodSecurity ===
pod/nothing-special-nginx created
Error from server (Forbidden): error when creating "./insecure-manifests/01-privileged-pod.yaml": pods "privileged-nginx" is forbidden: violates PodSecurity "restricted:latest": privileged (container "nginx" must not set securityContext.privileged=true), allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
Error from server (Forbidden): error when creating "./insecure-manifests/02-hostpath-pod.yaml": pods "hostpath-nginx" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), restricted volume types (volumes "host-root", "host-etc" use restricted volume type "hostPath"), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
Error from server (Forbidden): error when creating "./insecure-manifests/03-root-user-pod.yaml": pods "root-user-nginx" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "nginx" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "nginx" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "nginx" must set securityContext.runAsNonRoot=true), runAsUser=0 (container "nginx" must not set runAsUser=0), seccompProfile (pod or container "nginx" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
=== OPA Gatekeeper ===
pod/nothing-special-nginx created
Error from server (Forbidden): error when creating "./insecure-manifests/01-privileged-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [secure-pods-policy] Pod security context должен содержать runAsNonRoot: true
[secure-pods-policy] Контейнер 'nginx' не должен иметь privileged: true
Error from server (Forbidden): error when creating "./insecure-manifests/02-hostpath-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [secure-pods-policy] Pod security context должен содержать runAsNonRoot: true
[secure-pods-policy] Volume 'host-etc' не должен использовать hostPath
[secure-pods-policy] Volume 'host-root' не должен использовать hostPath
Error from server (Forbidden): error when creating "./insecure-manifests/03-root-user-pod.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [secure-pods-policy] Pod security context должен содержать runAsNonRoot: true
[secure-pods-policy] Контейнер 'nginx' не должен иметь runAsUser: 0 (root)
```

Т.е. в пространстве `insecure` создаётся всё, а в остальных пространствах -- только под `nothing-special-nginx `.


## Что с манифестами?
Их я честно сгенерировал Claude Sonnet 4 с небольшой ручной доработкой:
- [`insecure-manifests`](./insecure-manifests) -- 4 манифеста для проверочных подов (1 без привилегий и должен проходить везде, 3 с привилегиями и не должны проходить в пространствах, где привилегии запрещены);
- [`constraint-template.yaml`](constraint-template.yaml) -- constraint template для OPA Gatekeeper, который задаёт спецификацию проверки привилегий (имеет настраиваемый параметр `targetNamespace`)
- [`constraint.yaml`](constraint.yaml) -- привязка предыдущего constraint template на проверку привилегий конкретно в пространства `opa-gatekeeper-controlled`. 