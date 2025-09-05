# Доработки политики аудита для обнаружения критических угроз

## Проблемы текущей политики

### 1. Недостаточное логирование kubectl exec/debug команд
**Проблема:** Команды `kubectl exec` и `kubectl debug` не попадают в audit лог с достаточной детализацией.

**Текущая политика:**
```yaml
- level: RequestResponse
  resources:
    - group: ""
      resources: ["pods/exec", "pods/attach", "pods/portforward", "pods/ephemeralcontainers"]
```

### 2. Отсутствие специализированного мониторинга системных файлов
**Проблема:** Удаление критических файлов (например, audit-policy.yaml) не отслеживается.

## Ключевые улучшения

### 🔍 1. ОБНАРУЖЕНИЕ KUBECTL DEBUG КОМАНД

**Новое правило:**
```yaml
# KUBECTL DEBUG - обнаружение ephemeral containers
- level: RequestResponse
  verbs: ["create", "update", "patch"]
  resources:
    - group: ""
      resources: ["pods/ephemeralcontainers"]
```

**Что это дает:**
- Полное логирование всех `kubectl debug` команд
- Запись параметров запуска debug контейнеров
- Обнаружение несанкционированного доступа к хост-системе

### 🛡️ 2. ДЕТАЛЬНОЕ ЛОГИРОВАНИЕ EXEC КОМАНД

**Улучшенное правило:**
```yaml
# МОНИТОРИНГ ФАЙЛОВЫХ ОПЕРАЦИЙ через exec
- level: RequestResponse
  verbs: ["create"]
  resources:
    - group: ""
      resources: ["pods/exec"]
  # Логирует все exec команды с полными параметрами
```

**Что это дает:**
- Запись всех команд, выполняемых через `kubectl exec`
- Обнаружение попыток чтения/удаления системных файлов
- Возможность восстановить последовательность вредоносных действий

### 🚨 3. МОНИТОРИНГ СИСТЕМНЫХ NAMESPACE

**Новое правило:**
```yaml
# СИСТЕМНЫЕ NAMESPACE - повышенное внимание
- level: RequestResponse
  verbs: ["create", "delete", "update", "patch", "get", "list"]
  namespaces: ["kube-system", "kube-public", "kube-node-lease"]
  resources:
    - group: ""
      resources: ["*"]
```

**Что это дает:**
- Полное логирование всех операций в критических namespace
- Обнаружение несанкционированного доступа к системным ресурсам
- Мониторинг изменений в kube-system

### 🔐 4. ОБНАРУЖЕНИЕ ЭСКАЛАЦИИ ПРИВИЛЕГИЙ

**Специализированные правила:**
```yaml
# ESCALATION DETECTION
- level: RequestResponse
  verbs: ["create", "update", "patch"]
  resources:
    - group: "rbac.authorization.k8s.io"
      resources: ["rolebindings", "clusterrolebindings"]

# SERVICE ACCOUNT TOKEN REQUESTS
- level: RequestResponse
  verbs: ["create"]
  resources:
    - group: ""
      resources: ["serviceaccounts/token"]
```

**Что это дает:**
- Обнаружение создания опасных RBAC привязок
- Мониторинг запросов токенов ServiceAccount
- Выявление попыток получения cluster-admin прав

### 📊 5. МОНИТОРИНГ ПОДОЗРИТЕЛЬНЫХ ОБРАЗОВ

**Новое правило:**
```yaml
# ОБНАРУЖЕНИЕ ПОДОЗРИТЕЛЬНЫХ ОБРАЗОВ
- level: RequestResponse
  verbs: ["create", "update", "patch"]
  resources:
    - group: ""
      resources: ["pods"]
```

**Что это дает:**
- Логирование создания всех подов с полной конфигурацией
- Обнаружение использования образов для пентеста (nicolaka/netshoot)
- Выявление привилегированных подов

## Практическое применение

### Как обновить политику:

1. **Создать резервную копию:**
```bash
cp /etc/ssl/certs/audit-policy.yaml /etc/ssl/certs/audit-policy-backup.yaml
```

2. **Применить новую политику:**
```bash
cp audit-policy-enhanced.yaml /etc/ssl/certs/audit-policy.yaml
```

3. **Перезапустить kube-apiserver:**
```bash
# В minikube:
minikube stop && minikube start
```

### Проверка эффективности:

1. **Тест kubectl exec:**
```bash
kubectl exec -it privileged-pod -- cat /etc/passwd
```
Должно появиться в логе с уровнем RequestResponse.

2. **Тест kubectl debug:**
```bash
kubectl debug -n kube-system pod/storage-provisioner --image=nicolaka/netshoot
```
Должно логироваться создание ephemeral контейнера.

3. **Тест эскалации привилегий:**
```bash
kubectl create rolebinding test-escalation --clusterrole=cluster-admin --user=test
```
Должно попасть в лог с полными деталями.

## Дополнительные меры безопасности

### 1. Защита самой политики аудита
```yaml
# Специальное правило для мониторинга изменений audit policy
- level: RequestResponse
  verbs: ["update", "patch", "delete"]
  resources:
    - group: ""
      resources: ["configmaps"]
  resourceNames: ["audit-policy"]
```

### 2. Мониторинг критических файлов хоста
Рекомендуется дополнительно использовать:
- **Falco** для мониторинга файловой системы хоста
- **OPA Gatekeeper** для предотвращения создания опасных ресурсов
- **Pod Security Standards** для блокировки привилегированных подов

### 3. Алертинг в реальном времени
```bash
# Пример мониторинга через journalctl
journalctl -u kubelet -f | grep -E "(privileged|hostNetwork|hostPID)"
```

## Результат применения улучшений

После внедрения улучшенной политики аудита:

✅ **Будут обнаружены:**
- Все команды `kubectl exec` с параметрами
- Команды `kubectl debug` и создание ephemeral контейнеров  
- Попытки чтения/удаления системных файлов
- Эскалация привилегий через RBAC
- Создание привилегированных подов
- Несанкционированный доступ к системным namespace

✅ **Улучшенная безопасность:**
- Полная видимость вредоносной активности
- Возможность быстрого реагирования на инциденты
- Соответствие требованиям compliance
- Детальные forensic данные для расследования

Эта политика значительно повысит уровень безопасности кластера и обеспечит обнаружение всех критических угроз из вашего скрипта-имитатора.
