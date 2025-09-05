# Анализ событий безопасности в Kubernetes Audit Log

## Обзор

Данный документ содержит детальный анализ всех событий аудита Kubernetes, связанных с выполнением скрипта имитации инцидента безопасности `simulate_security_incident_reworked.sh`. Анализ проведен на основе audit log, собранного во время выполнения скрипта 4 сентября 2025 года в период с 22:59:35 до 22:59:50 UTC.

## Структура скрипта и соответствующие события

### 1. Создание привилегированного пода (22:59:41)

**Действие скрипта:**
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
    - name: host-proc
      mountPath: /host-proc
    - name: host-sys
      mountPath: /host-sys
  volumes:
  - name: host-root
    hostPath:
      path: /
  - name: host-proc
    hostPath:
      path: /proc
  - name: host-sys
    hostPath:
      path: /sys
EOF
```

**Соответствующие события аудита:**

#### 1.1 Проверка существования пода
```json
{
  "auditID": "f6fd01a5-b423-49ae-ad0a-bd5ed518fdbf",
  "timestamp": "2025-09-04T22:59:41.446594901Z",
  "verb": "get",
  "requestURI": "/api/v1/namespaces/default/pods/privileged-pod",
  "user": {"username": "minikube-user", "groups": ["system:masters", "system:authenticated"]},
  "responseStatus": {"code": 404, "message": "pods \"privileged-pod\" not found"}
}
```

**Анализ:** Kubectl сначала проверяет, существует ли под с именем `privileged-pod`. Получение 404 ошибки подтверждает, что под не существует и может быть создан.

#### 1.2 Создание привилегированного пода
```json
{
  "auditID": "0727bed5-f861-4ca6-8e44-b9f71f5c84e7",
  "timestamp": "2025-09-04T22:59:41.448541567Z",
  "verb": "create",
  "requestURI": "/api/v1/namespaces/default/pods",
  "user": {"username": "minikube-user", "groups": ["system:masters", "system:authenticated"]},
  "responseStatus": {"code": 201},
  "requestObject": {
    "spec": {
      "hostNetwork": true,
      "hostPID": true,
      "hostIPC": true,
      "containers": [{
        "securityContext": {"privileged": true},
        "volumeMounts": [
          {"mountPath": "/host", "name": "host-root"},
          {"mountPath": "/host-proc", "name": "host-proc"},
          {"mountPath": "/host-sys", "name": "host-sys"}
        ]
      }],
      "volumes": [
        {"hostPath": {"path": "/"}, "name": "host-root"},
        {"hostPath": {"path": "/proc"}, "name": "host-proc"},
        {"hostPath": {"path": "/sys"}, "name": "host-sys"}
      ]
    }
  }
}
```

**🚨 КРИТИЧЕСКОЕ НАРУШЕНИЕ БЕЗОПАСНОСТИ:**
- **privileged: true** - контейнер получает все возможности root на хосте
- **hostNetwork: true** - контейнер использует сетевой namespace хоста
- **hostPID: true** - контейнер видит все процессы хоста
- **hostIPC: true** - контейнер может взаимодействовать с IPC хоста
- **hostPath монтирования** - полный доступ к файловой системе хоста (/, /proc, /sys)

#### 1.3 Планирование пода
```json
{
  "auditID": "3746a665-b284-4c2f-9359-3dfa1672ee09",
  "timestamp": "2025-09-04T22:59:41.454158128Z",
  "verb": "create",
  "requestURI": "/api/v1/namespaces/default/pods/privileged-pod/binding",
  "user": {"username": "system:kube-scheduler"},
  "responseStatus": {"code": 201}
}
```

**Анализ:** Kube-scheduler успешно назначил под на узел minikube. Отсутствие политик безопасности позволило создать крайне опасный под.

### 2. Ожидание готовности пода (22:59:41)

**Действие скрипта:**
```bash
kubectl wait --for=condition=Ready pod/privileged-pod --timeout=300s
```

**Соответствующие события:**

#### 2.1 Мониторинг состояния пода
```json
{
  "auditID": "02ac896a-d6f0-47b2-9f2e-eb0a6710fda8",
  "timestamp": "2025-09-04T22:59:41.596156825Z",
  "verb": "get",
  "requestURI": "/api/v1/namespaces/default/pods/privileged-pod",
  "responseObject": {
    "status": {
      "phase": "Pending",
      "conditions": [
        {"type": "Ready", "status": "False", "reason": "ContainersNotReady"}
      ]
    }
  }
}
```

#### 2.2 Наблюдение за изменениями пода
```json
{
  "auditID": "7f5c8145-2bb4-4d81-8d08-9560e936d979",
  "timestamp": "2025-09-04T22:59:41.600398495Z",
  "verb": "watch",
  "requestURI": "/api/v1/namespaces/default/pods?allowWatchBookmarks=true&fieldSelector=metadata.name%3Dprivileged-pod"
}
```

**Анализ:** Kubectl активно отслеживает состояние пода, ожидая его готовности для выполнения последующих команд.

### 3. Попытки выполнения команд в привилегированном поде

Хотя в предоставленном логе не видны события выполнения команд `kubectl exec`, скрипт планировал выполнить следующие опасные действия:

**Планируемые действия:**
1. `kubectl exec -it privileged-pod -- cat /host/etc/ssl/certs/audit-policy.yaml` - чтение политик аудита
2. `kubectl exec -it privileged-pod -- rm /host/etc/ssl/certs/audit-policy.yaml` - удаление политик аудита

**Потенциальные последствия:**
- Компрометация политик безопасности
- Отключение аудита системы
- Полный доступ к файловой системе хоста

### 4. Создание namespace secure-ops

**Планируемое действие:**
```bash
kubectl create ns secure-ops
```

**Анализ:** В предоставленном логе отсутствуют события создания namespace, что может указывать на то, что скрипт был прерван или не дошел до этого этапа.

### 5. Создание Service Account и эскалация привилегий

**Планируемые действия:**
```bash
kubectl create sa monitoring
kubectl run sooper-dooper-attacker-pod-from-hell --image=alpine --serviceaccount=monitoring
```

**Анализ:** События создания ServiceAccount и связанных RoleBinding не обнаружены в логе, что подтверждает прерывание выполнения скрипта.

## Системные события во время инцидента

### Активность Storage Provisioner

В течение всего периода наблюдается регулярная активность системного компонента storage-provisioner:

```json
{
  "user": {"username": "system:serviceaccount:kube-system:storage-provisioner"},
  "verb": "get/update",
  "requestURI": "/api/v1/namespaces/kube-system/endpoints/k8s.io-minikube-hostpath"
}
```

**Анализ:** Это нормальная системная активность, не связанная с инцидентом безопасности.

### Создание Service Account Token

```json
{
  "auditID": "0f006df6-d3f2-4cc1-b83d-a7b8c1f9ca65",
  "timestamp": "2025-09-04T22:59:41.645795861Z",
  "verb": "create",
  "requestURI": "/api/v1/namespaces/default/serviceaccounts/default/token",
  "user": {"username": "system:node:minikube"},
  "responseStatus": {"code": 201}
}
```

**Анализ:** Kubelet создает токен для default ServiceAccount, необходимый для работы привилегированного пода.

## Оценка рисков и рекомендации

### Критические уязвимости

1. **Отсутствие Pod Security Standards**
   - Система позволила создать под с `privileged: true`
   - Нет ограничений на hostPath монтирования
   - Отсутствуют политики безопасности

2. **Чрезмерные привилегии пользователя**
   - Пользователь `minikube-user` имеет права `system:masters`
   - Возможность создания любых ресурсов без ограничений

3. **Полная компрометация хоста**
   - Привилегированный контейнер с доступом к корневой ФС
   - Доступ к сетевому и процессному namespace хоста

### Рекомендации по защите

1. **Внедрить Pod Security Standards**
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: default
     labels:
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
   ```

2. **Настроить RBAC**
   - Удалить пользователей из группы `system:masters`
   - Создать роли с минимальными необходимыми привилегиями

3. **Внедрить Admission Controllers**
   - OPA Gatekeeper для политик безопасности
   - Falco для runtime мониторинга

4. **Улучшить аудит**
   - Настроить алерты на создание привилегированных подов
   - Мониторинг hostPath монтирований

## Заключение

Анализ показал успешное создание крайне опасного привилегированного пода, который предоставляет полный доступ к хост-системе. Отсутствие базовых механизмов защиты (Pod Security Standards, RBAC, Admission Controllers) позволило злоумышленнику получить root-доступ к кластеру и хост-системе.

Данный инцидент демонстрирует критическую важность внедрения многоуровневой системы безопасности в Kubernetes кластерах.
