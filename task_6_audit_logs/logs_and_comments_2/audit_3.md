# Анализ Audit Лога: Имитация Инцидента Безопасности

## Обзор

Данный документ содержит детальный анализ audit лога Kubernetes во время выполнения скрипта `simulate_security_incident_reworked.sh`. Скрипт имитирует вредоносную активность в кластере minikube, включая создание привилегированных подов, эскалацию привилегий и несанкционированный доступ к секретам.

**Период анализа:** 2025-09-04 23:57:47 - 23:58:44 UTC  
**Пользователь:** `minikube-user` (группы: `system:masters`, `system:authenticated`)  
**Источник IP:** 192.168.49.1 (внешний клиент kubectl)

---

## 1. Создание Привилегированного Пода

### Событие 1.1: Проверка существования пода
**Строка 16 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"12839f9a-ba1d-4a6b-b681-5c577bf3d5a0","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods/privileged-pod","verb":"get","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"pods","namespace":"default","name":"privileged-pod","apiVersion":"v1"},"responseStatus":{"metadata":{},"status":"Failure","message":"pods \"privileged-pod\" not found","reason":"NotFound","details":{"name":"privileged-pod","kind":"pods"},"code":404},"requestReceivedTimestamp":"2025-09-04T23:57:51.431791Z","stageTimestamp":"2025-09-04T23:57:51.433290Z","annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":""}}
```

**Анализ:** Пользователь `minikube-user` проверяет существование пода `privileged-pod` в namespace `default`. Под не найден (404), что ожидаемо перед его созданием. Это соответствует команде `kubectl apply` из скрипта.

### Событие 1.2: Создание привилегированного пода
**Строка 17 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"5490f5c0-6107-4045-ac29-1220d7d77aa8","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods?fieldManager=kubectl-client-side-apply&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"pods","namespace":"default","name":"privileged-pod","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"privileged-pod","namespace":"default"...},"spec":{"volumes":[{"name":"host-root","hostPath":{"path":"/","type":""}},{"name":"host-proc","hostPath":{"path":"/proc","type":""}},{"name":"host-sys","hostPath":{"path":"/sys","type":""}}],"containers":[{"name":"debug","image":"nicolaka/netshoot","command":["sleep","3600"],"securityContext":{"privileged":true},"volumeMounts":[{"name":"host-root","mountPath":"/host"},{"name":"host-proc","mountPath":"/host-proc"},{"name":"host-sys","mountPath":"/host-sys"}]}],"hostNetwork":true,"hostPID":true,"hostIPC":true}}
```

**🚨 КРИТИЧЕСКОЕ СОБЫТИЕ БЕЗОПАСНОСТИ:**
- Создан под с **привилегированным контекстом** (`"privileged":true`)
- Монтированы **критические директории хоста**: `/`, `/proc`, `/sys`
- Включены **опасные настройки**: `hostNetwork`, `hostPID`, `hostIPC`
- Используется образ `nicolaka/netshoot` для сетевой диагностики
- **Уровень угрозы: ВЫСОКИЙ** - полный доступ к хост-системе

---

## 2. Создание Namespace и Service Account

### Событие 2.1: Создание namespace secure-ops
**Строка 43 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"475e368e-a4fe-4f52-a1a0-4ec1fc075d79","stage":"ResponseComplete","requestURI":"/api/v1/namespaces?fieldManager=kubectl-create&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"namespaces","name":"secure-ops","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201}}
```

**Анализ:** Создан новый namespace `secure-ops`. Название может вводить в заблуждение, создавая ложное впечатление о безопасности операций в этом пространстве имен.

### Событие 2.2: Создание service account monitoring
**Строка 46 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"3cf7653e-a6df-439c-bd5f-e743641eef76","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/secure-ops/serviceaccounts?fieldManager=kubectl-create&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"serviceaccounts","namespace":"secure-ops","name":"monitoring","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201}}
```

**Анализ:** Создан service account `monitoring` в namespace `secure-ops`. Название "monitoring" может маскировать вредоносные намерения под видом мониторинга системы.

---

## 3. Проверка Привилегий и Эскалация

### Событие 3.1: Первая проверка доступа к секретам
**Строка 47 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"82743a43-d953-41e5-889f-c169b2f6e0d8","stage":"ResponseComplete","requestURI":"/apis/authorization.k8s.io/v1/selfsubjectaccessreviews","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"impersonatedUser":{"username":"system:serviceaccount:secure-ops:monitoring","groups":["system:serviceaccounts","system:serviceaccounts:secure-ops","system:authenticated"]},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"selfsubjectaccessreviews","apiGroup":"authorization.k8s.io","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"SelfSubjectAccessReview","apiVersion":"authorization.k8s.io/v1","metadata":{"creationTimestamp":null},"spec":{"resourceAttributes":{"namespace":"secure-ops","verb":"get","resource":"secrets"}},"status":{"allowed":false}}}
```

**Анализ:** Выполнена проверка `kubectl auth can-i get secrets` от имени service account `monitoring`. Результат: **доступ запрещен** (`"allowed":false`). Это разведывательная операция перед эскалацией привилегий.

### Событие 3.2: Создание RoleBinding для эскалации привилегий (secure-ops)
**Строка 49 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"bf5451ee-5a66-4892-9c36-e435d53a5b17","stage":"ResponseComplete","requestURI":"/apis/rbac.authorization.k8s.io/v1/namespaces/secure-ops/rolebindings?fieldManager=kubectl-client-side-apply&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"rolebindings","namespace":"secure-ops","name":"escalate-binding","apiGroup":"rbac.authorization.k8s.io","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"RoleBinding","apiVersion":"rbac.authorization.k8s.io/v1","metadata":{"name":"escalate-binding","namespace":"secure-ops"},"subjects":[{"kind":"ServiceAccount","name":"monitoring","namespace":"kube-system"}],"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"cluster-admin"}}}
```

**🚨 КРИТИЧЕСКОЕ СОБЫТИЕ БЕЗОПАСНОСТИ:**
- Создан RoleBinding `escalate-binding` в namespace `secure-ops`
- Service account `monitoring` получает роль **`cluster-admin`**
- **ОШИБКА В СКРИПТЕ**: SA указан в namespace `kube-system` вместо `secure-ops`
- **Уровень угрозы: КРИТИЧЕСКИЙ** - попытка получения полных административных привилегий

### Событие 3.3: Создание RoleBinding для эскалации привилегий (kube-system)
**Строка 51 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"d6804864-0e88-44bb-9874-42f611fb03c8","stage":"ResponseComplete","requestURI":"/apis/rbac.authorization.k8s.io/v1/namespaces/kube-system/rolebindings?fieldManager=kubectl-client-side-apply&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"rolebindings","namespace":"kube-system","name":"escalate-binding-kube-system","apiGroup":"rbac.authorization.k8s.io","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"RoleBinding","apiVersion":"rbac.authorization.k8s.io/v1","metadata":{"name":"escalate-binding-kube-system","namespace":"kube-system"},"subjects":[{"kind":"ServiceAccount","name":"monitoring","namespace":"secure-ops"}],"roleRef":{"apiGroup":"rbac.authorization.k8s.io","kind":"ClusterRole","name":"cluster-admin"}}}
```

**🚨 КРИТИЧЕСКОЕ СОБЫТИЕ БЕЗОПАСНОСТИ:**
- Создан RoleBinding `escalate-binding-kube-system` в **критическом namespace `kube-system`**
- Service account `monitoring` из `secure-ops` получает роль **`cluster-admin`** в системном пространстве
- **Уровень угрозы: КРИТИЧЕСКИЙ** - полная компрометация системного namespace

### Событие 3.4: Повторная проверка доступа к секретам
**Строка 52 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"d4a0c37a-5099-45c7-8e06-f7851f097ba3","stage":"ResponseComplete","requestURI":"/apis/authorization.k8s.io/v1/selfsubjectaccessreviews","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"impersonatedUser":{"username":"system:serviceaccount:secure-ops:monitoring","groups":["system:serviceaccounts","system:serviceaccounts:secure-ops","system:authenticated"]},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"selfsubjectaccessreviews","apiGroup":"authorization.k8s.io","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"SelfSubjectAccessReview","apiVersion":"authorization.k8s.io/v1","metadata":{"creationTimestamp":null},"spec":{"resourceAttributes":{"namespace":"secure-ops","verb":"get","resource":"secrets"}},"status":{"allowed":false}}}
```

**Анализ:** Повторная проверка доступа к секретам после создания RoleBinding. Результат по-прежнему `"allowed":false`, что указывает на то, что эскалация привилегий в namespace `secure-ops` не сработала из-за ошибки в скрипте.

---

## 4. Несанкционированный Доступ к Секретам

### Событие 4.1: Получение списка секретов (администратор)
**Строка 53 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"94114b0d-3306-4bf8-8250-234d1eeff3e4","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/kube-system/secrets?limit=500","verb":"list","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"secrets","namespace":"kube-system","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":200}}
```

**🚨 СОБЫТИЕ БЕЗОПАСНОСТИ:**
- Получен полный список секретов из **критического namespace `kube-system`**
- Выполнено от имени администратора (`minikube-user`)
- **Уровень угрозы: ВЫСОКИЙ** - разведка чувствительных данных

### Событие 4.2: Доступ к секретам через эскалированный SA
**Строка 54 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"ace1924d-1b46-4764-9197-df38007a722c","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/kube-system/secrets?limit=500","verb":"list","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"impersonatedUser":{"username":"system:serviceaccount:secure-ops:monitoring","groups":["system:serviceaccounts","system:serviceaccounts:secure-ops","system:authenticated"]},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"secrets","namespace":"kube-system","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":200},"annotations":{"authorization.k8s.io/decision":"allow","authorization.k8s.io/reason":"RBAC: allowed by RoleBinding \"escalate-binding-kube-system/kube-system\" of ClusterRole \"cluster-admin\" to ServiceAccount \"monitoring/secure-ops\""}}
```

**🚨 КРИТИЧЕСКОЕ СОБЫТИЕ БЕЗОПАСНОСТИ:**
- **УСПЕШНАЯ ЭСКАЛАЦИЯ ПРИВИЛЕГИЙ**: Service account `monitoring` получил доступ к секретам
- Доступ разрешен через RoleBinding `escalate-binding-kube-system` с ролью `cluster-admin`
- Выполнена **имперсонация** (`impersonatedUser`) для обхода ограничений
- **Уровень угрозы: КРИТИЧЕСКИЙ** - компрометация системных секретов

### Событие 4.3-4.4: Дополнительные запросы секретов
**Строки 55-56 лога:** Аналогичные запросы списка секретов от имени администратора, подтверждающие продолжение разведывательной деятельности.

---

## 5. Доступ к Системным Подам

### Событие 5.1: Получение информации о storage-provisioner
**Строка 57 лога:**
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Request","auditID":"2aaa9275-07e1-40c4-8919-e16a39996f85","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/kube-system/pods/storage-provisioner","verb":"get","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=ab71fd6be6c1e4d403d28fab508b648190a61332f8c107fc9b2fa35966ccee0e"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"pods","namespace":"kube-system","name":"storage-provisioner","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":200}}
```

**Анализ:** Получена информация о системном поде `storage-provisioner` в namespace `kube-system`. Это подготовка к использованию `kubectl debug` для доступа к файловой системе хоста.

### Событие 5.2: Список подов storage-provisioner
**Строка 58 лога:** Дополнительный запрос для получения списка подов `storage-provisioner`, подтверждающий подготовку к debug-операциям.

---

## Выводы и Рекомендации

### Обнаруженные Угрозы:

1. **Создание привилегированного пода** с полным доступом к хост-системе
2. **Эскалация привилегий** через создание RoleBinding с ролью cluster-admin
3. **Несанкционированный доступ к секретам** в критическом namespace kube-system
4. **Разведывательная деятельность** по системным подам и ресурсам
5. **Использование имперсонации** для обхода ограничений безопасности

### Индикаторы Компрометации (IoC):

- **Пользователь:** `minikube-user`
- **IP-адрес:** 192.168.49.1
- **User-Agent:** `kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42`
- **Временной интервал:** 2025-09-04 23:57:51 - 23:58:24 UTC
- **Созданные ресурсы:**
  - Pod: `privileged-pod` (namespace: default)
  - Namespace: `secure-ops`
  - ServiceAccount: `monitoring` (namespace: secure-ops)
  - RoleBinding: `escalate-binding` (namespace: secure-ops)
  - RoleBinding: `escalate-binding-kube-system` (namespace: kube-system)

### Рекомендации по Безопасности:

1. **Немедленно удалить** все созданные ресурсы
2. **Проверить Pod Security Standards** для предотвращения создания привилегированных подов
3. **Настроить мониторинг** создания RoleBinding с ролью cluster-admin
4. **Ограничить доступ** к namespace kube-system
5. **Внедрить политики безопасности** (OPA Gatekeeper, Falco)
6. **Регулярно аудировать** RBAC-конфигурации

### Статус Инцидента:
**КРИТИЧЕСКИЙ** - Полная компрометация кластера через эскалацию привилегий и доступ к системным ресурсам.
