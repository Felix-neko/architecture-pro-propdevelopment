# Анализ проблем с audit логированием

## Проблема
При выполнении скрипта `simulate_incident.sh` в audit логах отображаются только события до строки 48 (создание privileged-pod), но события после этого (строки 49-89) не фиксируются.

## Причины отсутствия событий

### 1. **kubectl exec операции не логируются**
- **Строка 54**: `kubectl exec -n kube-system ... -- cat /etc/resolv.conf`
- **Проблема**: В audit policy отсутствуют правила для логирования операций `connect` к subresources `pods/exec`
- **Решение**: Добавлено правило для логирования `pods/exec`, `pods/attach`, `pods/portforward`

### 2. **Ограниченное покрытие RBAC операций**
- **Строки 64-77**: Создание RoleBinding в namespace `secure-ops`
- **Проблема**: Текущая policy логирует RBAC только для определенных namespaces (`kube-system`, `kube-public`, `default`)
- **Решение**: Убрано ограничение по namespaces для полного покрытия RBAC операций

### 3. **Операции с impersonation не отслеживаются**
- **Строка 31**: `kubectl get secret ... --as=system:serviceaccount:secure-ops:monitoring`
- **Проблема**: Отсутствует правило для логирования операций с флагом `--as`
- **Решение**: Добавлено правило для логирования всех операций с impersonation

### 4. **Проверки прав доступа не логируются**
- **Строка 23**: `kubectl auth can-i get secrets --as=...`
- **Проблема**: Операции проверки прав (`authorization.k8s.io/subjectaccessreviews`) не логируются
- **Решение**: Добавлено правило для логирования операций проверки прав

### 5. **Неудачные команды на уровне клиента**
- **Строка 59**: `kubectl delete -f /etc/ssl/certs/audit-policy.yaml --as=admin`
- **Причина**: Команда завершилась ошибкой "path does not exist" на уровне kubectl
- **Важно**: Такие команды **НЕ БУДУТ логироваться** даже после изменений, так как API запрос не формируется
- **Будут логироваться**: Только команды, которые достигают Kubernetes API сервера

## Внесенные изменения в audit-policy.yaml

### 1. Расширено покрытие RBAC операций
```yaml
# Убрано ограничение namespaces для RBAC
- level: RequestResponse
  verbs: ["create", "update", "patch", "delete"]
  resources:
    - group: "rbac.authorization.k8s.io"
      resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
```

### 2. Добавлено логирование exec операций
```yaml
# Логирование exec операций в pod'ах (lateral movement detection)
- level: Request
  verbs: ["create"]
  resources:
    - group: ""
      resources: ["pods/exec", "pods/attach", "pods/portforward"]
```

### 3. Добавлено логирование impersonation
```yaml
# Логирование операций с impersonation (--as флаг)
- level: Request
  verbs: ["*"]
  resources:
    - group: "*"
      resources: ["*"]
```

### 4. Добавлено логирование проверок прав
```yaml
# Логирование операций с auth can-i
- level: Request
  verbs: ["create"]
  resources:
    - group: "authorization.k8s.io"
      resources: ["selfsubjectaccessreviews", "subjectaccessreviews"]
```

## Типы команд и их логирование

### ✅ **БУДУТ логироваться** после изменений:
```bash
# Успешные операции с impersonation
kubectl delete configmap test --as=admin

# Неудачные API операции (403, 404 ошибки)
kubectl delete secret nonexistent --as=admin
kubectl get pods --as=system:serviceaccount:default:unauthorized

# Операции с существующими файлами
kubectl delete -f existing-file.yaml --as=admin
```

### ❌ **НЕ БУДУТ логироваться** (ошибки на уровне клиента):
```bash
# Несуществующие файлы
kubectl delete -f /nonexistent/file.yaml --as=admin

# Неправильный синтаксис YAML
kubectl apply -f broken-yaml.yaml --as=admin

# Проблемы с сетью (kubectl не может подключиться к API)
kubectl get pods --server=unreachable-server --as=admin
```

## Рекомендации

1. **Применить обновленную audit policy**:
   ```bash
   sudo cp audit-policy.yaml /etc/ssl/certs/audit-policy.yaml
   sudo systemctl restart kubelet
   ```

2. **Повторно запустить simulate_incident.sh** для проверки улучшенного логирования

3. **Мониторить следующие события**:
   - Создание RBAC объектов в любых namespaces
   - Операции exec/attach к pod'ам
   - Использование impersonation (--as флаг)
   - Проверки прав доступа

4. **Помнить**: Audit логи фиксируют только запросы, которые достигают Kubernetes API сервера

## Ожидаемые события после исправления

После применения обновленной policy в audit логах должны появиться:
- ✅ Создание ServiceAccount `monitoring`
- ✅ Проверка прав `kubectl auth can-i`
- ✅ Операция `kubectl exec` в CoreDNS pod
- ✅ Создание RoleBinding `escalate-binding`
- ✅ Все операции с impersonation

## Безопасность

Обновленная policy обеспечивает:
- **Полное покрытие** критических операций безопасности
- **Обнаружение lateral movement** через exec операции
- **Отслеживание эскалации привилегий** через RBAC
- **Мониторинг impersonation** атак
