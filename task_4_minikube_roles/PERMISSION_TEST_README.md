# Kubernetes Permission Testing Script

Скрипт для тестирования прав доступа пользователей Kubernetes в различных namespace.

## Описание

`test_permissions.py` - это Python-скрипт, который тестирует различные операции Kubernetes для проверки прав доступа пользователей. Скрипт выполняет следующие операции:

### Тестируемые операции:

1. **Чтение списка namespace** - проверяет базовый доступ к кластеру
2. **Операции с ConfigMap:**
   - Создание/перезапись ConfigMap с тестовыми данными
   - Чтение списка ConfigMap в namespace
3. **Операции с Secret:**
   - Создание/перезапись Secret с ключом `foo=bar`
   - Получение списка Secret
   - Чтение данных из Secret (включая ключ `foo`)
4. **Операции с Pod:**
   - Создание/перезапись Pod с nginx (`hello-pod`)
   - Просмотр логов Pod

### Целевые namespace:
- Все namespace с префиксом `sales-services-*`
- Все namespace с префиксом `owner-services-*`

## Установка зависимостей

### С использованием uv (рекомендуется):
```bash
# Установка uv (если не установлен)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Установка зависимостей
uv sync
```

### Альтернативно с pip:
```bash
pip3 install kubernetes>=28.1.0 PyYAML>=6.0
```

## Использование

### Базовое использование (kubeconfig по умолчанию):
```bash
python3 test_permissions.py
```

### Использование с конкретным kubeconfig:
```bash
python3 test_permissions.py --kubeconfig kubeconfig_anton
```

### Примеры тестирования разных ролей:
```bash
# Тест с правами администратора (minikube)
python3 test_permissions.py

# Тест с правами sales-developers (только чтение)
python3 test_permissions.py --kubeconfig users/kubeconfig_anton

# Тест с правами sales-devops (развертывание приложений)
python3 test_permissions.py --kubeconfig users/kubeconfig_bruno

# Тест с правами sales-lead-devops (чтение секретов)
python3 test_permissions.py --kubeconfig users/kubeconfig_caesar
```

## Интерпретация результатов

Скрипт выводит результаты в виде таблицы с цветными индикаторами:

- ✅ **Зеленая галочка** - операция выполнена успешно
- ❌ **Красный крестик** - операция завершилась ошибкой (нет прав доступа)

### Пример вывода:
```
Namespace            | CM Create  | CM Read   | Sec Create  | Sec List  | Sec Read  | Pod Create  | Pod Logs 
--------------------------------------------------------------------------------------------------------------------
sales-services-prod  | ✅         | ✅        | ❌          | ✅        | ❌        | ✅          | ✅       
sales-services-dev   | ✅         | ✅        | ❌          | ✅        | ❌        | ✅          | ✅       
sales-services-test1 | ✅         | ✅        | ✅          | ✅        | ✅        | ✅          | ✅       
```

## Расшифровка колонок таблицы

| Колонка | Описание |
|---------|----------|
| **CM Create** | Создание/обновление ConfigMap |
| **CM Read** | Чтение списка ConfigMap |
| **Sec Create** | Создание/обновление Secret |
| **Sec List** | Получение списка Secret |
| **Sec Read** | Чтение данных из Secret |
| **Pod Create** | Создание/обновление Pod |
| **Pod Logs** | Просмотр логов Pod |

## Ожидаемые результаты для разных ролей

### sales-developers (sales-app-viewer):
- ✅ CM Read, Sec List, Pod Logs
- ❌ CM Create, Sec Create, Sec Read, Pod Create

### sales-devops (sales-app-deployer + sales-config-editor):
- ✅ CM Create, CM Read, Pod Create, Pod Logs
- ✅ Sec Create, Sec List (без чтения содержимого)
- ❌ Sec Read (в production)
- ✅ Sec Read (в тестовых средах)

### sales-lead-devops (sales-secrets-reader):
- ✅ Все операции чтения (CM Read, Sec List, Sec Read, Pod Logs)
- ❌ Операции создания (CM Create, Sec Create, Pod Create)

## Устранение неполадок

### Ошибка "kubeconfig file not found":
Убедитесь, что путь к kubeconfig файлу указан правильно.

### Ошибка "Forbidden":
У пользователя нет прав для выполнения операции - это ожидаемое поведение для тестирования ролей.

### Ошибка "No such namespace":
Создайте namespace с префиксами `sales-services-` или `owner-services-` для тестирования.

## Очистка ресурсов

Скрипт создает тестовые ресурсы:
- ConfigMap: `test-config`
- Secret: `test-secret`  
- Pod: `hello-pod`

Для очистки выполните:
```bash
kubectl delete configmap test-config --all-namespaces
kubectl delete secret test-secret --all-namespaces
kubectl delete pod hello-pod --all-namespaces
```
