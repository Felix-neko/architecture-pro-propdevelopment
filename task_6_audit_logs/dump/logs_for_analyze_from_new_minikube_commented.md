# Анализ аудит-логов Kubernetes с комментариями

## Введение

Данный документ содержит подробный анализ аудит-логов Kubernetes с объяснением каждого типа событий и их значения для безопасности кластера.

## Структура аудит-события Kubernetes

Каждое событие в аудит-логах содержит следующие ключевые поля:

### Основные поля события:
- **kind**: Тип объекта (всегда "Event" для аудит-событий)
- **apiVersion**: Версия API аудита (audit.k8s.io/v1)
- **level**: Уровень детализации логирования
  - `Metadata` - только метаданные запроса/ответа
  - `Request` - метаданные + тело запроса
  - `RequestResponse` - метаданные + тело запроса и ответа
- **auditID**: Уникальный идентификатор аудит-события
- **stage**: Этап обработки запроса
  - `RequestReceived` - запрос получен API-сервером
  - `ResponseStarted` - начало отправки ответа
  - `ResponseComplete` - ответ полностью отправлен
- **verb**: HTTP-метод (get, list, create, update, delete, watch)
- **requestURI**: URI запроса к API
- **user**: Информация о пользователе/сервисном аккаунте
- **sourceIPs**: IP-адреса источника запроса
- **userAgent**: User-Agent клиента
- **objectRef**: Ссылка на объект Kubernetes
- **responseStatus**: Статус HTTP-ответа
- **annotations**: Дополнительная информация (авторизация, причины)

---

## Анализ событий по типам

### 1. ИНИЦИАЛИЗАЦИЯ КЛАСТЕРА

#### Событие: Получение списка PriorityClasses
```json
// ЗАПРОС: Получение списка классов приоритетов
{
  "stage": "RequestReceived",
  "verb": "list",
  "requestURI": "/apis/scheduling.k8s.io/v1/priorityclasses?limit=500&resourceVersion=0",
  "user": {"username": "system:apiserver"}
}
```
**Значение**: API-сервер запрашивает список классов приоритетов для инициализации планировщика. Это нормальная операция при запуске кластера.

```json
// ОТВЕТ: Успешное получение списка
{
  "stage": "ResponseComplete",
  "responseStatus": {"code": 200},
  "annotations": {
    "authorization.k8s.io/decision": "allow"
  }
}
```
**Значение**: Запрос успешно выполнен, авторизация пройдена.

---

### 2. СЕТЕВЫЕ РЕСУРСЫ

#### Событие: Получение IngressClasses
```json
{
  "verb": "list",
  "requestURI": "/apis/networking.k8s.io/v1/ingressclasses?limit=500&resourceVersion=0",
  "user": {"username": "system:apiserver"}
}
```
**Значение**: Загрузка конфигурации Ingress-контроллеров. Важно для маршрутизации внешнего трафика.

#### Событие: Получение IP-адресов
```json
{
  "verb": "list",
  "requestURI": "/apis/networking.k8s.io/v1/ipaddresses?limit=500&resourceVersion=0"
}
```
**Значение**: Управление IP-адресами в кластере. Критично для сетевой безопасности.

---

### 3. РАСШИРЕНИЯ И CRD

#### Событие: Получение CustomResourceDefinitions
```json
{
  "verb": "list",
  "requestURI": "/apis/apiextensions.k8s.io/v1/customresourcedefinitions?limit=500&resourceVersion=0"
}
```
**Значение**: Загрузка пользовательских ресурсов. Может указывать на установленные операторы или расширения.

---

### 4. КОНФИГУРАЦИЯ И СЕКРЕТЫ

#### Событие: Поиск ConfigMap для отслеживания токенов
```json
{
  "level": "RequestResponse",
  "verb": "list",
  "requestURI": "/api/v1/namespaces/kube-system/configmaps?fieldSelector=metadata.name%3Dkube-apiserver-legacy-service-account-token-tracking",
  "responseObject": {"items": []}
}
```
**Значение**: API-сервер ищет ConfigMap для отслеживания устаревших токенов сервисных аккаунтов. Пустой результат означает, что ConfigMap не существует.

#### Событие: Получение списка ServiceAccounts
```json
{
  "verb": "list",
  "requestURI": "/api/v1/serviceaccounts?limit=500&resourceVersion=0",
  "responseObject": {"items": []}
}
```
**Значение**: Загрузка сервисных аккаунтов. Пустой список указывает на свежий кластер.

#### Событие: Получение списка Secrets
```json
{
  "level": "RequestResponse",
  "verb": "list",
  "requestURI": "/api/v1/secrets?limit=500&resourceVersion=0",
  "responseObject": {"items": []}
}
```
**Значение**: Загрузка секретов. Критично для безопасности - пустой список нормален для нового кластера.

---

### 5. УЗЛЫ КЛАСТЕРА

#### Событие: Kubelet ищет свой узел
```json
{
  "verb": "list",
  "requestURI": "/api/v1/nodes?fieldSelector=metadata.name%3Dminikube",
  "user": {"username": "system:node:minikube"},
  "sourceIPs": ["192.168.49.2"]
}
```
**Значение**: Kubelet на узле minikube ищет информацию о себе. Нормальная операция при запуске узла.

#### Событие: Создание узла
```json
{
  "verb": "create",
  "requestURI": "/api/v1/nodes",
  "user": {"username": "system:node:minikube"}
}
```
**Значение**: Kubelet пытается зарегистрировать узел в кластере. Критическая операция для добавления вычислительных ресурсов.

#### Событие: Получение узла (неудача)
```json
{
  "verb": "get",
  "requestURI": "/api/v1/nodes/minikube",
  "responseStatus": {
    "status": "Failure",
    "message": "nodes \"minikube\" not found",
    "code": 404
  }
}
```
**Значение**: Узел еще не зарегистрирован в кластере. Это временное состояние при инициализации.

---

### 6. ХРАНИЛИЩЕ

#### Событие: Получение PersistentVolumes
```json
{
  "verb": "list",
  "requestURI": "/api/v1/persistentvolumes?limit=500&resourceVersion=0"
}
```
**Значение**: Загрузка информации о постоянных томах. Важно для управления данными.

#### Событие: Получение CSI драйверов
```json
{
  "verb": "list",
  "requestURI": "/apis/storage.k8s.io/v1/csidrivers?limit=500&resourceVersion=0",
  "user": {"username": "system:node:minikube"}
}
```
**Значение**: Kubelet запрашивает список CSI драйверов для работы с хранилищем.

#### Событие: Получение CSI узла (неудача)
```json
{
  "verb": "get",
  "requestURI": "/apis/storage.k8s.io/v1/csinodes/minikube",
  "responseStatus": {
    "message": "csinodes.storage.k8s.io \"minikube\" not found",
    "code": 404
  }
}
```
**Значение**: CSI узел еще не зарегистрирован. Нормально при первом запуске.

---

### 7. RBAC И АВТОРИЗАЦИЯ

#### Событие: Получение ClusterRoleBindings
```json
{
  "level": "RequestResponse",
  "verb": "list",
  "requestURI": "/apis/rbac.authorization.k8s.io/v1/clusterrolebindings?limit=500&resourceVersion=0",
  "responseObject": {"items": []}
}
```
**Значение**: Загрузка привязок кластерных ролей. Пустой список означает отсутствие настроенных RBAC правил.

#### Событие: Получение RoleBindings
```json
{
  "verb": "list",
  "requestURI": "/apis/rbac.authorization.k8s.io/v1/rolebindings?limit=500&resourceVersion=0",
  "responseObject": {"items": []}
}
```
**Значение**: Загрузка привязок ролей в пространствах имен.

#### Событие: Получение ClusterRoles
```json
{
  "level": "RequestResponse",
  "verb": "list",
  "requestURI": "/apis/rbac.authorization.k8s.io/v1/clusterroles?limit=500&resourceVersion=0",
  "responseObject": {"items": []}
}
```
**Значение**: Загрузка кластерных ролей. Критично для системы авторизации.

---

### 8. МОНИТОРИНГ И WATCH

#### Событие: Установка Watch на VolumeAttachments
```json
{
  "verb": "watch",
  "requestURI": "/apis/storage.k8s.io/v1/volumeattachments?allowWatchBookmarks=true&resourceVersion=2&timeout=5m10s&timeoutSeconds=310&watch=true",
  "stage": "ResponseStarted"
}
```
**Значение**: API-сервер устанавливает долгосрочное соединение для отслеживания изменений в подключениях томов.

#### Событие: Watch на Secrets
```json
{
  "verb": "watch",
  "requestURI": "/api/v1/secrets?allowWatchBookmarks=true&resourceVersion=2&timeout=8m4s&timeoutSeconds=484&watch=true"
}
```
**Значение**: Мониторинг изменений в секретах. Критично для безопасности.

---

### 9. СЕРВИСЫ И СЕТЬ

#### Событие: Получение Services с фильтром
```json
{
  "verb": "list",
  "requestURI": "/api/v1/services?fieldSelector=spec.clusterIP%21%3DNone&limit=500&resourceVersion=0",
  "user": {"username": "system:node:minikube"}
}
```
**Значение**: Kubelet получает список сервисов с ClusterIP (исключая headless сервисы) для настройки сетевых правил.

---

### 10. ПЛАНИРОВЩИК

#### Событие: Получение конфигурации аутентификации
```json
{
  "level": "RequestResponse",
  "verb": "get",
  "requestURI": "/api/v1/namespaces/kube-system/configmaps/extension-apiserver-authentication",
  "user": {"username": "system:kube-scheduler"}
}
```
**Значение**: Планировщик получает конфигурацию для аутентификации с расширенными API-серверами.

---

## Анализ безопасности

### Нормальные операции:
1. ✅ Все запросы от системных компонентов (system:apiserver, system:node:minikube, system:kube-scheduler)
2. ✅ Успешная авторизация всех запросов (authorization.k8s.io/decision: "allow")
3. ✅ Отсутствие подозрительных IP-адресов (только localhost ::1 и внутренний IP 192.168.49.2)

### Потенциальные проблемы:
1. ⚠️ Пустые списки RBAC ресурсов могут указывать на отсутствие настроенной системы авторизации
2. ⚠️ Множественные 404 ошибки при поиске узлов и CSI ресурсов (нормально при инициализации)

### Рекомендации:
1. Настроить RBAC политики для ограничения доступа
2. Мониторить создание новых узлов и сервисных аккаунтов
3. Отслеживать доступ к секретам и конфигурационным картам
4. Настроить алерты на неудачные попытки авторизации

---

## Заключение

Анализируемые логи показывают нормальный процесс инициализации кластера Kubernetes. Все операции выполняются системными компонентами с соответствующими правами доступа. Отсутствуют признаки вредоносной активности или нарушений безопасности.

Основные наблюдения:
- Кластер находится в процессе первоначальной настройки
- Узел minikube регистрируется в кластере
- Системные компоненты загружают необходимые ресурсы
- RBAC система не настроена (пустые списки ролей)
- Отсутствуют пользовательские ресурсы и приложения
