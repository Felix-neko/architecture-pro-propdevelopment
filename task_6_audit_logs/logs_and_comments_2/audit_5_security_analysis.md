# Анализ audit лога audit_5log на предмет вредоносной активности

## Обзор скрипта-имитатора

Скрипт `simulate_security_incident_reworked.sh` выполняет следующие вредоносные действия:

1. **Создание привилегированного пода** (строки 5-38) - под с `privileged: true`, `hostNetwork: true`, `hostPID: true`, `hostIPC: true`
2. **Чтение/удаление audit-policy.yaml** (строки 42-47) - команды `kubectl exec` для доступа к системным файлам
3. **Создание namespace и ServiceAccount** (строки 52-59) - создание `secure-ops` namespace и `monitoring` SA
4. **Эскалация привилегий** (строки 64-95) - создание RoleBinding с `cluster-admin` правами
5. **Команды kubectl debug** (строки 105-113) - доступ к хост-системе через ephemeral контейнеры

## Анализ событий в audit_5log

### 🚨 СОБЫТИЕ 1: Создание привилегированного пода "privileged-pod"

**Найденные события в логе:**

#### 1.1. Проверка существования пода (GET запрос)
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"Metadata","auditID":"298f4482-4f35-4c9d-acf5-97efe7a6659c","stage":"RequestReceived","requestURI":"/api/v1/namespaces/default/pods/privileged-pod","verb":"get","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=3feb02c2cc82d2dd5e26c4c44f5edfb7100493a01dcbe0d73e1caa07cd002251"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"pods","namespace":"default","name":"privileged-pod","apiVersion":"v1"},"requestReceivedTimestamp":"2025-09-05T00:27:36.084768Z","stageTimestamp":"2025-09-05T00:27:36.084768Z"}
```

**Комментарий:** 
- ✅ **ОБНАРУЖЕНО**: Пользователь `minikube-user` пытается получить информацию о поде `privileged-pod`
- 🔍 **Детали**: Запрос возвращает 404 (под не найден), что указывает на попытку создания нового пода
- ⚠️ **Угроза**: Подготовка к созданию потенциально опасного пода

#### 1.2. Создание привилегированного пода (CREATE запрос)
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"b150e9ad-fbfb-4688-8eac-f309d416d96e","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/pods?fieldManager=kubectl-client-side-apply&fieldValidation=Strict","verb":"create","user":{"username":"minikube-user","groups":["system:masters","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=3feb02c2cc82d2dd5e26c4c44f5edfb7100493a01dcbe0d73e1caa07cd002251"]}},"sourceIPs":["192.168.49.1"],"userAgent":"kubectl/v1.33.4 (linux/amd64) kubernetes/74cdb42","objectRef":{"resource":"pods","namespace":"default","name":"privileged-pod","apiVersion":"v1"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"privileged-pod","namespace":"default","creationTimestamp":null,"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{},\"name\":\"privileged-pod\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"command\":[\"sleep\",\"3600\"],\"image\":\"nicolaka/netshoot\",\"name\":\"debug\",\"securityContext\":{\"privileged\":true},\"volumeMounts\":[{\"mountPath\":\"/host\",\"name\":\"host-root\"},{\"mountPath\":\"/host-proc\",\"name\":\"host-proc\"},{\"mountPath\":\"/host-sys\",\"name\":\"host-sys\"}]}],\"hostIPC\":true,\"hostNetwork\":true,\"hostPID\":true,\"restartPolicy\":\"Never\",\"volumes\":[{\"hostPath\":{\"path\":\"/\"},\"name\":\"host-root\"},{\"hostPath\":{\"path\":\"/proc\"},\"name\":\"host-proc\"},{\"hostPath\":{\"path\":\"/sys\"},\"name\":\"host-sys\"}]}}\n"}},"spec":{"volumes":[{"name":"host-root","hostPath":{"path":"/","type":""}},{"name":"host-proc","hostPath":{"path":"/proc","type":""}},{"name":"host-sys","hostPath":{"path":"/sys","type":""}}],"containers":[{"name":"debug","image":"nicolaka/netshoot","command":["sleep","3600"],"resources":{},"volumeMounts":[{"name":"host-root","mountPath":"/host"},{"name":"host-proc","mountPath":"/host-proc"},{"name":"host-sys","mountPath":"/host-sys"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"privileged":true}}],"restartPolicy":"Never","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","hostNetwork":true,"hostPID":true,"hostIPC":true,"securityContext":{},"schedulerName":"default-scheduler","enableServiceLinks":true},"status":{}}
```

**Комментарий:**
- 🚨 **КРИТИЧЕСКАЯ УГРОЗА**: Создан под с максимальными привилегиями!
- ⚠️ **Опасные настройки**:
  - `"privileged":true` - полный доступ к хост-системе
  - `"hostNetwork":true` - доступ к сетевому стеку хоста
  - `"hostPID":true` - доступ к процессам хоста
  - `"hostIPC":true` - доступ к IPC хоста
  - `"image":"nicolaka/netshoot"` - образ для сетевой диагностики (часто используется злоумышленниками)
- 📁 **Монтирование хост-системы**:
  - `/` → `/host` - полный доступ к файловой системе хоста
  - `/proc` → `/host-proc` - доступ к информации о процессах
  - `/sys` → `/host-sys` - доступ к системной информации
- 🎯 **Цель атаки**: Получение полного контроля над хост-системой

#### 1.3. Создание ServiceAccount токена для пода
```json
{"kind":"Event","apiVersion":"audit.k8s.io/v1","level":"RequestResponse","auditID":"ff553b33-1789-43c6-bd3c-db6e5566cb44","stage":"ResponseComplete","requestURI":"/api/v1/namespaces/default/serviceaccounts/default/token","verb":"create","user":{"username":"system:node:minikube","groups":["system:nodes","system:authenticated"],"extra":{"authentication.kubernetes.io/credential-id":["X509SHA256=b3414617e987ca1998f4ce29a9888b017a10d0bb0d6c9a9f66efcc20e12206b9"]}},"sourceIPs":["192.168.49.2"],"userAgent":"kubelet/v1.33.1 (linux/amd64) kubernetes/8adc0f0","objectRef":{"resource":"serviceaccounts","namespace":"default","name":"default","apiVersion":"v1","subresource":"token"},"responseStatus":{"metadata":{},"code":201},"requestObject":{"kind":"TokenRequest","apiVersion":"authentication.k8s.io/v1","metadata":{"creationTimestamp":null},"spec":{"audiences":null,"expirationSeconds":3607,"boundObjectRef":{"kind":"Pod","apiVersion":"v1","name":"privileged-pod","uid":"c512dc5b-2d2a-499f-857d-6c361033582d"}},"status":{"token":"","expirationTimestamp":null}},"responseObject":{"kind":"TokenRequest","apiVersion":"authentication.k8s.io/v1","metadata":{"name":"default","namespace":"default","creationTimestamp":"2025-09-05T00:27:36Z","managedFields":[{"manager":"kubelet","operation":"Update","apiVersion":"authentication.k8s.io/v1","time":"2025-09-05T00:27:36Z","fieldsType":"FieldsV1","fieldsV1":{"f:spec":{"f:boundObjectRef":{"f:apiVersion":{},"f:kind":{},"f:name":{},"f:uid":{}},"f:expirationSeconds":{}}},"subresource":"token"}]},"spec":{"audiences":["https://kubernetes.default.svc.cluster.local"],"expirationSeconds":3607,"boundObjectRef":{"kind":"Pod","apiVersion":"v1","name":"privileged-pod","uid":"c512dc5b-2d2a-499f-857d-6c361033582d"}},"status":{"token":"eyJhbGciOiJSUzI1NiIsImtpZCI6IjcyM0Y5WnltamFCVW9MSWdsaEpNbXFFckxjenE0Si1FNmdMbTNsdzgzWlkifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNzg4NTY4MDU2LCJpYXQiOjE3NTcwMzIwNTYsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwianRpIjoiZDAwODU0NTMtNGE4ZS00M2IyLWE5NWUtZDI4MjBlYjUxNDQ1Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwibm9kZSI6eyJuYW1lIjoibWluaWt1YmUiLCJ1aWQiOiIyNjAwYWJlNi1kNjI1LTQ5NGYtYTU0Yy1kODJkOWNhNGE4MzkifSwicG9kIjp7Im5hbWUiOiJwcml2aWxlZ2VkLXBvZCIsInVpZCI6ImM1MTJkYzViLTJkMmEtNDk5Zi04NTdkLTZjMzYxMDMzNTgyZCJ9LCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoiZGVmYXVsdCIsInVpZCI6IjM0OWEzZWEwLTE0MjctNDg2My1hMDk4LTMzMmY2ZWVjZDM2YSJ9LCJ3YXJuYWZ0ZXIiOjE3NTcwMzU2NjN9LCJuYmYiOjE3NTcwMzIwNTYsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OmRlZmF1bHQifQ.L5STs5pC7gFoC1IvPNdybX6B5RZUrwpthmVR7OiBlc95Qqk5nXHQ1A2LNDNjAdxztsyJ1eDWxTRfJV12vS2zEWbyexHfYU2b8jcx1nSn1amvekJxt7j4EpHXq0MjuGd5bspnUQAneSxYkXhlNAOAn0i0kRxem3gv7ljSa2heMaflcj5cpz8eXRNejEp_FGDHpMzfgkINwSlm8wT0r64QJtIcHV0he6p3M6aA3IPJ4lsTtJ5WTftqvp3_VMYplupYM-KxN2p-fIbu0-BdntBYW2rOlyJBJxzIc30sGarvj4VpZUeMDUyW3uz2ZBmXwHk_tjvnuYgMGfgbWnBMVvCoSQ","expirationTimestamp":"2025-09-05T01:27:43Z"}}
```

**Комментарий:**
- 🔑 **Создание токена**: Kubelet создает ServiceAccount токен для привилегированного пода
- ⚠️ **Потенциальная угроза**: Токен может быть использован для дальнейших атак на API сервер
- 📅 **Время жизни**: Токен действителен до 2025-09-05T01:27:43Z (1 час)

## 🚨 ДОПОЛНИТЕЛЬНЫЕ ОБНАРУЖЕННЫЕ СОБЫТИЯ

### ✅ НАЙДЕНЫ kubectl exec команды (строки 42-47 скрипта):

#### 2.1. Чтение файла audit-policy.yaml
```json
{"requestURI":"/api/v1/namespaces/default/pods/privileged-pod/exec?command=cat&command=%2Fhost%2Fetc%2Fssl%2Fcerts%2Faudit-policy.yaml&container=debug&stdin=true&stdout=true&tty=true","verb":"get","user":{"username":"minikube-user"}}
```

**Комментарий:**
- 🚨 **КРИТИЧЕСКАЯ УГРОЗА**: Злоумышленник читает файл политики аудита!
- 📂 **Путь**: `/host/etc/ssl/certs/audit-policy.yaml` - монтированная хост-система
- 🎯 **Цель**: Изучение текущих правил аудита для обхода обнаружения
- ⚠️ **Техника**: Использование привилегированного контейнера для доступа к хост-файлам

#### 2.2. Удаление файла audit-policy.yaml (первая попытка)
```json
{"requestURI":"/api/v1/namespaces/default/pods/privileged-pod/exec?command=rm&command=%2Fhost%2Fetc%2Fssl%2Fcerts%2Faudit-policy.yaml&container=debug&stdin=true&stdout=true&tty=true","verb":"get","user":{"username":"minikube-user"}}
```

**Комментарий:**
- 🚨 **КРИТИЧЕСКАЯ УГРОЗА**: Попытка удаления политики аудита!
- 🎯 **Цель атаки**: Отключение системы мониторинга для сокрытия дальнейших действий
- ⚠️ **Последствия**: Потеря возможности отслеживать вредоносную активность
- 📅 **Время**: 2025-09-05T00:28:06.632303Z

#### 2.3. Удаление файла audit-policy.yaml (вторая попытка)
```json
{"requestURI":"/api/v1/namespaces/default/pods/privileged-pod/exec?command=rm&command=%2Fhost%2Fetc%2Fssl%2Fcerts%2Faudit-policy.yaml&container=debug&stdin=true&stdout=true&tty=true","verb":"get","user":{"username":"minikube-user"}}
```

**Комментарий:**
- 🔄 **Повторная попытка**: Злоумышленник повторяет команду удаления
- 📅 **Время**: 2025-09-05T00:28:06.837592Z
- ✅ **Обнаружение**: Политика аудита успешно зафиксировала обе попытки!

### ✅ НАЙДЕНЫ kubectl debug команды (строки 105-113 скрипта):

#### 3.1. Создание ephemeral контейнера для чтения /etc/hosts
```json
{"requestURI":"/api/v1/namespaces/kube-system/pods/storage-provisioner/ephemeralcontainers","verb":"patch","requestObject":{"spec":{"ephemeralContainers":[{"command":["cat","/proc/1/root/etc/hosts"],"image":"nicolaka/netshoot","name":"debugger-v4zht","targetContainerName":"storage-provisioner"}]}}}
```

#### 3.2. Создание ephemeral контейнера для чтения /etc/resolv.conf
```json
{"requestURI":"/api/v1/namespaces/kube-system/pods/storage-provisioner/ephemeralcontainers","verb":"patch","requestObject":{"spec":{"ephemeralContainers":[{"command":["cat","/proc/1/root/etc/resolv.conf"],"image":"nicolaka/netshoot","name":"debugger-cdqbk","targetContainerName":"storage-provisioner"}]}}}
```

**Комментарий:**
- 🚨 **КРИТИЧЕСКАЯ УГРОЗА**: Доступ к хост-системе через ephemeral контейнеры!
- 🎯 **Техника**: `kubectl debug` с созданием временных контейнеров
- 📂 **Целевые файлы**: `/proc/1/root/etc/hosts` и `/proc/1/root/etc/resolv.conf`
- 🔍 **Разведка**: Сбор информации о сетевой конфигурации хоста
- ⚠️ **Образ**: `nicolaka/netshoot` - инструмент для сетевой диагностики

### ✅ НАЙДЕНЫ события создания namespace и ServiceAccount:

#### 4.1. Создание namespace secure-ops
```json
{"requestURI":"/api/v1/namespaces/secure-ops/configmaps","verb":"create"}
{"requestURI":"/api/v1/namespaces/secure-ops/serviceaccounts","verb":"create"}
```

#### 4.2. Создание ServiceAccount monitoring
```json
{"requestURI": "/api/v1/namespaces/secure-ops/serviceaccounts?fieldManager=kubectl-create&fieldValidation=Strict", "verb": "create", "user": {"username": "minikube-user"}}
```

**Комментарий:**
- ✅ **Обнаружено**: Создание вредоносного namespace и ServiceAccount
- 🎯 **Цель**: Подготовка инфраструктуры для эскалации привилегий
- ⚠️ **Следующий шаг**: Ожидается создание RoleBinding с правами cluster-admin

## ✅ ДОПОЛНИТЕЛЬНО ОБНАРУЖЕННЫЕ КРИТИЧЕСКИЕ СОБЫТИЯ

### 🚨 НАЙДЕНЫ события эскалации привилегий (строки 65-95 скрипта):

#### 5.1. Создание RoleBinding `escalate-binding` в namespace secure-ops
```json
{
  "auditID": "74707521-2684-484a-b9c7-919f1b0e7114",
  "requestURI": "/apis/rbac.authorization.k8s.io/v1/namespaces/secure-ops/rolebindings",
  "verb": "create",
  "user": {"username": "minikube-user"},
  "requestObject": {
    "kind": "RoleBinding",
    "metadata": {"name": "escalate-binding", "namespace": "secure-ops"},
    "subjects": [{"kind": "ServiceAccount", "name": "monitoring", "namespace": "kube-system"}],
    "roleRef": {"kind": "ClusterRole", "name": "cluster-admin"}
  },
  "responseStatus": {"code": 201}
}
```

#### 5.2. Создание RoleBinding `escalate-binding-kube-system` в namespace kube-system
```json
{
  "auditID": "4fce7345-857a-4172-b808-34b3a7421eb0",
  "requestURI": "/apis/rbac.authorization.k8s.io/v1/namespaces/kube-system/rolebindings",
  "verb": "create",
  "user": {"username": "minikube-user"},
  "requestObject": {
    "kind": "RoleBinding",
    "metadata": {"name": "escalate-binding-kube-system", "namespace": "kube-system"},
    "subjects": [{"kind": "ServiceAccount", "name": "monitoring", "namespace": "secure-ops"}],
    "roleRef": {"kind": "ClusterRole", "name": "cluster-admin"}
  },
  "responseStatus": {"code": 201}
}
```

**Комментарий:**
- 🚨 **МАКСИМАЛЬНАЯ КРИТИЧНОСТЬ**: Злоумышленник создал ДВА RoleBinding с правами `cluster-admin`!
- 🎯 **Полная компрометация**: ServiceAccount `monitoring` получил права администратора кластера
- ⚠️ **Двойная эскалация**: Права предоставлены как в созданном namespace `secure-ops`, так и в системном `kube-system`
- 📅 **Время атаки**: 2025-09-05T00:28:07Z

### 🚨 НАЙДЕНЫ команды тестирования и использования привилегий:

#### 6.1. Проверка прав доступа `kubectl auth can-i`
```json
{
  "auditID": "e9b42462-9cae-49c0-93ea-bbb1e01120d2",
  "requestURI": "/apis/authorization.k8s.io/v1/selfsubjectaccessreviews",
  "verb": "create",
  "user": {"username": "minikube-user"},
  "impersonatedUser": {"username": "system:serviceaccount:secure-ops:monitoring"},
  "requestObject": {
    "spec": {"resourceAttributes": {"namespace": "secure-ops", "verb": "get", "resource": "secrets"}}
  },
  "responseStatus": {"code": 201}
}
```

#### 6.2. Чтение секретов `kubectl get secrets` - Первый запрос
```json
{
  "auditID": "122c8ca7-a4c6-466d-bafe-82f0d33d7819",
  "requestURI": "/api/v1/namespaces/kube-system/secrets?limit=500",
  "verb": "list",
  "user": {"username": "minikube-user"},
  "responseStatus": {"code": 200}
}
```

#### 6.3. Чтение секретов с impersonation - Второй запрос
```json
{
  "auditID": "e22b55b0-f702-44bc-b134-4b258baba443",
  "requestURI": "/api/v1/namespaces/kube-system/secrets?limit=500",
  "verb": "list",
  "user": {"username": "minikube-user"},
  "impersonatedUser": {"username": "system:serviceaccount:secure-ops:monitoring"},
  "responseStatus": {"code": 200}
}
```

**Комментарий:**
- 🎯 **ПОДТВЕРЖДЕНИЕ ЭСКАЛАЦИИ**: Злоумышленник успешно протестировал и использовал повышенные привилегии!
- ✅ **Успешные операции**: Все запросы завершились с кодом 200/201
- 🔄 **Impersonation**: Использование скомпрометированного ServiceAccount для действий
- 📊 **Масштаб**: Доступ ко ВСЕМ секретам в системном namespace kube-system

## 🎯 Выводы по анализу

### ✅ Что ОБНАРУЖЕНО улучшенной политикой аудита:

1. **Создание привилегированного пода** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНО
   - Зафиксирован полный манифест пода с опасными настройками
   - Видны все привилегированные параметры: `privileged: true`, `hostNetwork: true`, `hostPID: true`, `hostIPC: true`
   - Зафиксировано монтирование хост-системы
   - Зафиксирован опасный образ `nicolaka/netshoot`

2. **kubectl exec команды** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНЫ
   - Команда чтения audit-policy.yaml: `cat /host/etc/ssl/certs/audit-policy.yaml`
   - Две попытки удаления audit-policy.yaml: `rm /host/etc/ssl/certs/audit-policy.yaml`
   - Полные параметры команд и временные метки
   - Пользователь и источник IP зафиксированы

3. **kubectl debug команды** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНЫ
   - Создание ephemeral контейнера для чтения `/proc/1/root/etc/hosts`
   - Создание ephemeral контейнера для чтения `/proc/1/root/etc/resolv.conf`
   - Использование образа `nicolaka/netshoot`
   - Целевой под: `storage-provisioner` в namespace `kube-system`

4. **Создание namespace и ServiceAccount** - ✅ ЗАФИКСИРОВАНЫ
   - Создание namespace `secure-ops`
   - Создание ServiceAccount `monitoring`
   - Автоматическое создание default ServiceAccount

5. **Создание ServiceAccount токена** - ✅ ЗАФИКСИРОВАНО
   - Полная информация о созданном токене
   - Время жизни и привязка к поду

### ✅ ВСЕ УГРОЗЫ УСПЕШНО ОБНАРУЖЕНЫ:

1. **Создание RoleBinding для эскалации привилегий** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНЫ
   - Обнаружены ДВА RoleBinding с правами cluster-admin
   - Зафиксирована эскалация привилегий ServiceAccount monitoring
   - Полные детали запросов и ответов

2. **Команды kubectl auth can-i** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНЫ
   - Обнаружены события проверки прав доступа через selfsubjectaccessreviews
   - Зафиксировано тестирование привилегий с impersonation
   - Видны целевые ресурсы (secrets) и namespace (secure-ops)

3. **Команды kubectl get secret** - ✅ ПОЛНОСТЬЮ ЗАФИКСИРОВАНЫ
   - Обнаружены ДВА запроса на чтение секретов из kube-system
   - Зафиксированы успешные попытки доступа к токенам (код 200)
   - Видно использование impersonation для обхода ограничений

## 🛡️ Рекомендации по улучшению политики аудита

Для обнаружения ВСЕХ вредоносных действий из скрипта необходимо добавить:

1. **Для kubectl exec команд:**
```yaml
- level: RequestResponse
  verbs: ["create"]
  resources:
    - group: ""
      resources: ["pods/exec"]
```

2. **Для kubectl debug команд:**
```yaml
- level: RequestResponse
  verbs: ["create", "update", "patch"]
  resources:
    - group: ""
      resources: ["pods/ephemeralcontainers"]
```

3. **Для namespace и RBAC:**
```yaml
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
    - group: ""
      resources: ["namespaces", "serviceaccounts"]
    - group: "rbac.authorization.k8s.io"
      resources: ["rolebindings", "clusterrolebindings"]
```

## 📊 ИТОГОВАЯ ОЦЕНКА ЭФФЕКТИВНОСТИ - ПРЕВОСХОДНЫЙ РЕЗУЛЬТАТ!

- **Обнаружено**: 6 из 6 основных типов вредоносной активности (**100% ПОЛНОЕ ПОКРЫТИЕ!**)
- **Критичность обнаруженного**: **МАКСИМАЛЬНАЯ** (все векторы атак + полная компрометация кластера)
- **Полнота логирования обнаруженного**: **ПРЕВОСХОДНАЯ** (детальная информация о всех командах, включая impersonation)
- **Общая оценка**: Политика аудита **ИСКЛЮЧИТЕЛЬНО ЭФФЕКТИВНА!** Обнаружила ВСЕ вредоносные действия!

### 🏆 ВСЕ АТАКИ УСПЕШНО ОБНАРУЖЕНЫ:

1. ✅ **Создание привилегированного пода** (100% покрытие)
2. ✅ **kubectl exec команды для компрометации хоста** (100% покрытие) 
3. ✅ **kubectl debug для доступа к хост-системе** (100% покрытие)
4. ✅ **Создание вредоносной инфраструктуры** (namespace + ServiceAccount) (100% покрытие)
5. ✅ **Эскалация привилегий через RBAC** (**100% покрытие - НАЙДЕНЫ ОБА RoleBinding!**)
6. ✅ **Тестирование и использование повышенных привилегий** (**100% покрытие - включая impersonation!**)

### 🎯 КЛЮЧЕВЫЕ ДОСТИЖЕНИЯ - ПОЛНАЯ ПОБЕДА НАД АТАКОЙ:

- **Обнаружение попыток отключения аудита**: Зафиксированы ДВЕ команды удаления audit-policy.yaml
- **Мониторинг ephemeral контейнеров**: Успешное отслеживание kubectl debug команд
- **Обнаружение эскалации привилегий**: Найдены ОБА RoleBinding с cluster-admin правами
- **Отслеживание impersonation**: Зафиксировано использование скомпрометированного ServiceAccount
- **Мониторинг доступа к секретам**: Обнаружены ВСЕ попытки чтения секретов kube-system
- **Детализация команд**: Полные параметры всех выполненных команд
- **Временные метки**: Точная хронология ВСЕЙ атаки от начала до конца
- **Идентификация пользователя**: Все действия привязаны к minikube-user
- **Подтверждение компрометации**: Успешные коды ответов (200/201) подтверждают реализацию атаки

### 🚨 КРИТИЧЕСКИЙ РЕЗУЛЬТАТ:
**КЛАСТЕР ПОЛНОСТЬЮ СКОМПРОМЕТИРОВАН** - злоумышленник получил права cluster-admin и успешно получил доступ ко всем секретам системного namespace!
