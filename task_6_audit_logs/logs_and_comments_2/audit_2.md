# Анализ Audit Log: События скрипта имитации вредоносной активности

## Обзор
Данный анализ содержит события из Kubernetes audit лога, связанные с выполнением скрипта имитации вредоносной активности. Скрипт выполнялся с **02:43:10 до 02:43:52 MSK** (23:43:10 - 23:43:52 UTC).

## Важное наблюдение
⚠️ **КРИТИЧЕСКАЯ ПРОБЛЕМА**: В предоставленном audit логе отсутствуют события пользовательских операций из скрипта. Лог содержит только системные события от `storage-provisioner`, `kube-controller-manager` и других системных компонентов.

Это может указывать на:
1. **Неправильную конфигурацию audit policy** - пользовательские события могли быть отфильтрованы
2. **Неполный лог** - события могли попасть в другую часть лога
3. **Проблемы с логированием** - audit система могла не зафиксировать пользовательские операции

## Ожидаемые события (которые должны были попасть в лог)

### 1. Создание привилегированного пода `privileged-pod`
**Операция из скрипта:** `kubectl apply -f -` (создание Pod)
**Ожидаемое событие:** 
- `verb: "create"`
- `resource: "pods"`
- `objectRef.name: "privileged-pod"`
- `level: "RequestResponse"` (согласно audit policy)

**Анализ:** Это критически важное событие безопасности - создание пода с привилегированным доступом (`privileged: true`), доступом к host network, PID и IPC namespace, а также монтированием корневой файловой системы хоста.

### 2. Операции kubectl exec в привилегированном поде
**Операции из скрипта:**
- `kubectl exec -it privileged-pod -- cat /host/etc/ssl/certs/audit-policy.yaml`
- `kubectl exec -it privileged-pod -- rm /host/etc/ssl/certs/audit-policy.yaml`

**Ожидаемые события:**
- `verb: "create"`
- `resource: "pods/exec"`
- `level: "RequestResponse"` (согласно audit policy)

**Анализ:** Эти операции представляют **крайне высокий риск безопасности**:
- Чтение конфиденциальных файлов хоста (audit policy)
- **УДАЛЕНИЕ audit policy файла** - попытка отключить логирование безопасности

### 3. Создание namespace `secure-ops`
**Операция из скрипта:** `kubectl create ns secure-ops`
**Ожидаемое событие:**
- `verb: "create"`
- `resource: "namespaces"`
- `objectRef.name: "secure-ops"`
- `level: "RequestResponse"`

**Анализ:** Создание namespace может быть подготовкой к атаке - изоляция вредоносных ресурсов.

### 4. Создание ServiceAccount `monitoring`
**Операция из скрипта:** `kubectl create sa monitoring`
**Ожидаемое событие:**
- `verb: "create"`
- `resource: "serviceaccounts"`
- `objectRef.name: "monitoring"`
- `level: "RequestResponse"`

**Анализ:** Создание ServiceAccount для последующей эскалации привилегий.

### 5. Операции проверки прав доступа (can-i)
**Операции из скрипта:**
- `kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring`

**Ожидаемые события:**
- `verb: "create"`
- `resource: "selfsubjectaccessreviews"` или `"subjectaccessreviews"`
- `level: "Request"`
- Наличие impersonation headers (`--as` флаг)

**Анализ:** Разведка прав доступа - типичное поведение атакующего для понимания доступных привилегий.

### 6. Создание RoleBinding для эскалации привилегий
**Операции из скрипта:**
- Создание `escalate-binding` RoleBinding
- Создание `escalate-binding-kube-system` RoleBinding

**Ожидаемые события:**
- `verb: "create"`
- `resource: "rolebindings"`
- `level: "RequestResponse"`
- `roleRef.name: "cluster-admin"`

**Анализ:** **КРИТИЧЕСКАЯ угроза безопасности** - предоставление ServiceAccount прав cluster-admin, что дает полный контроль над кластером.

### 7. Чтение секретов
**Операции из скрипта:**
- `kubectl get secret -n kube-system` (с impersonation)
- `kubectl get secret -n kube-system` (без impersonation)

**Ожидаемые события:**
- `verb: "get"` или `"list"`
- `resource: "secrets"`
- `namespace: "kube-system"`
- `level: "Request"`

**Анализ:** Доступ к секретам kube-system namespace - потенциальное извлечение критически важных данных (токены, сертификаты).

### 8. Операции kubectl debug (ephemeral containers)
**Операции из скрипта:**
- `kubectl debug -n kube-system pod/storage-provisioner`

**Ожидаемые события:**
- `verb: "create"`, `"update"` или `"patch"`
- `resource: "pods/ephemeralcontainers"`
- `level: "RequestResponse"`

**Анализ:** Создание ephemeral контейнеров для доступа к файловой системе хоста через существующий pod - обход security контекстов.

## Системные события в логе

Из предоставленного лога видны следующие системные события в период выполнения скрипта:

### События storage-provisioner
```json
{"auditID":"479ad2ac-fbe0-4407-b272-43d2f9634111","requestURI":"/api/v1/namespaces/kube-system/endpoints/k8s.io-minikube-hostpath","verb":"get","user":{"username":"system:serviceaccount:kube-system:storage-provisioner"}}
```
**Анализ:** Рутинные операции storage-provisioner для управления persistent volumes.

### События kube-controller-manager
```json
{"auditID":"489a43fe-e760-4c7b-bcc8-3c76f27b04b4","requestURI":"/api","verb":"get","user":{"username":"system:serviceaccount:kube-system:resourcequota-controller"}}
```
**Анализ:** API discovery операции от resourcequota-controller.

## Выводы и рекомендации

### 🚨 Критические проблемы:
1. **Отсутствие пользовательских событий в логе** - возможная компрометация системы логирования
2. **Потенциальное удаление audit policy** - если операция из скрипта была успешной

### 🔍 Необходимые действия:
1. **Проверить полный audit лог** - возможно, события находятся в другой части
2. **Проверить конфигурацию audit policy** - убедиться, что пользовательские операции логируются
3. **Проверить статус audit policy файла** на хосте minikube
4. **Проанализировать другие источники логов** (kubelet, container runtime)

### 📋 Индикаторы компрометации (IoC):
- Создание привилегированных подов с доступом к хосту
- Операции kubectl exec в системных подах
- Создание RoleBinding с cluster-admin правами
- Операции impersonation (`--as` флаг)
- Создание ephemeral контейнеров в системных подах
- Доступ к секретам kube-system namespace

### 🛡️ Рекомендации по безопасности:
1. Настроить **Pod Security Standards** для предотвращения создания привилегированных подов
2. Использовать **OPA Gatekeeper** для контроля RBAC операций
3. Настроить **мониторинг в реальном времени** для критических операций
4. Регулярно **ротировать секреты** и токены ServiceAccount
5. Ограничить использование **kubectl debug** и **kubectl exec**

---
*Анализ выполнен: 2025-09-05*
*Период анализа: 23:43:10 - 23:43:52 UTC*
