# Задание 4. Защита доступа к кластеру Kubernetes

### Роли для namespace

| Роль                    | Права роли                                                                                                           | Группы пользователей                        |
|-------------------------|----------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| `app-viewer`     | get/list/watch ресурсов в namespace, просмотр логов                                                                  | `{team}-developers`                         |
| `app-deployer`   | управление Deployments/ReplicaSets/StatefulSets/Jobs/CRs, чтение ConfigMap, создание/обновление Secrets (без чтения) | `{team}-devops`                             |
| `service-editor` | управление сервисами и ingress'ами в namespace                                                                       | `{team}-devops`                             |
| `config-editor`  | создание и редактирование ConfigMap (без чтения секретов)                                                            | `{team}-devops`                             |
| `secret-reader`  | чтение секретов в namespace                                                                                          | `{team}-lead-devops` (раздавать минимально) |
| `admin`          | полный контроль внутри namespace                                                                                     | `{team}-devops` (lead dev/owner)            |

### Кластерные роли

| Роль  | Права роли | Группы пользователей |
| --- | --- | --- |
| `cluster-viewer` | просмотр всех namespaces для аудита | `security-group` |
| `cluster-maintainer` | управление глобальными ресурсами: storageclasses, CRDs | `platform-admins` |
| `ingress-admin` | управление ингрессами и сервисами, включая load balancer'ы | `{team}-devops` |
| `storage-admin` | создание/удаление PV, управление CSI | `platform-admins` |


### Группы пользователей

- `platform-admins`: имеют полный доступ к кластеру (в будущем заменить на ограниченный `cluster-admin`)
- `{team}-lead-devops`: старший девопс (считаем, что таковых по одному на домен)
- `{team}-devops`: девопсы каждой продуктовой команды, имеют высокие права, включая управление сервисами, хранилищами, бэкапом;
- `{team}-developers`: разработчики каждой продуктовой команды, имеют доступ на просмотр состояний и чтение логов сервисов; 
- `{team}-managers`: это операционная команда каждой продуктовой команды (менеджеры), имеют доступ к админ-панелям сервисов, но внутрь Kubernetes не ходят;
- `security-group`: специалисты ИБ, имеют доступ на чтение логов во всех пространствах для аудита безопасности (секреты читать не могут).

### Пространства

**Sales Services:**
- `sales-services-prod` - продуктовая среда для сервисов продаж
- `sales-services-dev` - предпродуктовая для сервисов продаж  
- `sales-services-test1` - тестовая среда 1 для сервисов продаж
- `sales-services-test2` - тестовая среда 2 для сервисов продаж
- `sales-services-test3` - тестовая среда 3 для сервисов продаж

**Owner Services:**
- `owner-services-prod` - продуктовая среда для сервисов владельцев
- `owner-services-dev` - предпродуктовая для сервисов владельцев
- `owner-services-test1` - тестовая среда 1 для сервисов владельцев
- `owner-services-test2` - тестовая среда 2 для сервисов владельцев
- `owner-services-test3` - тестовая среда 3 для сервисов владельцев

**BI Services:**
- `bi-services-prod` - продуктовая среда для BI сервисов
- `bi-services-test` - тестовая среда для BI сервисов

**Accounting Services:**
- `accounting-services-prod` - продуктовая среда для сервисов бухгалтерии
- `accounting-services-test` - тестовая среда для сервисов бухгалтерии

**Auth Services:**
- `auth-services-prod` - продуктовая среда для сервисов аутентификации
- `auth-services-test` - тестовая среда для сервисов аутентификации

## Примеры ролей и пользователей

Для практической части я создал только нескольких пользователей и часть ролей из этого списка (только то, что нужно для их пользователей):
- `anton`: разработчик из домена клиентских сервисов, может просматривать ресурсы (кроме секретов) во всех пространствах `sales-services-*` и редактировать любые ресурсы в `sales-serices-test*`;
- `bruno`: девопс из домена клиентских сервисов, имеет дополнительные права на создание и изменение ресурсов во всех пространствах `sales-services-*` (секреты в этих пространствах читать по-прежнему не может, хотя может создавать и изменять);
- `caesar`: старший девопс домена клиентских сервисов, имеет дополнительные права на чтение секретов в `sales-services-*`;
- `dora`: специалист ИБ, умеет читать состояние всех сервисов (кроме секретов) на всём кластере.

### Как протестировать
Создаём minikube:
```bash
bash setup_minikube.sh
bash create_namespaces.sh
bash create_roles_and_bindings.sh
bash create_example_users.sh
```

После этого вызываем скрипт `test_permissions.py` (не забудьте сделать `uv sync`) и смотрим проверку прав для разных юзеров:
#### anton
```bash
uv run python3 ./test_permissions.py --kubeconfig=users/kubeconfig_anton
```

В конце должно выдать:
```
     Namespace         CM Create    CM Read    Sec Create    Sec List    Sec Read    Pod List    Pod Create    Pod Logs    Svc List    Svc Create
--------------------  -----------  ---------  ------------  ----------  ----------  ----------  ------------  ----------  ----------  ------------
 owner-services-dev        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-prod        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test1       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test2       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test3       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
 sales-services-dev        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
sales-services-prod        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
sales-services-test1       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test2       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test3       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
```
(поды создавать может только в тестовых средах своего домена)

#### bruno
```bash
uv run python3 ./test_permissions.py --kubeconfig=users/kubeconfig_bruno
```
В конце должно выдать:
```
     Namespace         CM Create    CM Read    Sec Create    Sec List    Sec Read    Pod List    Pod Create    Pod Logs    Svc List    Svc Create
--------------------  -----------  ---------  ------------  ----------  ----------  ----------  ------------  ----------  ----------  ------------
 owner-services-dev        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-prod        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test1       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test2       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test3       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
 sales-services-dev        ✓           ✓           ✓            ✓           ✗           ✓            ✓            ✓           ✓            ✓
sales-services-prod        ✓           ✓           ✓            ✓           ✗           ✓            ✓            ✓           ✓            ✓
sales-services-test1       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test2       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test3       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
```
(добавилось создание подов в продуктовой и предпродуктовой среде, чтение секретов -- всё ещё только в тестовых пространствах)

#### caesar
```bash
uv run python3 ./test_permissions.py --kubeconfig=users/kubeconfig_caesar
```
В конце должно выдать:
```
     Namespace         CM Create    CM Read    Sec Create    Sec List    Sec Read    Pod List    Pod Create    Pod Logs    Svc List    Svc Create
--------------------  -----------  ---------  ------------  ----------  ----------  ----------  ------------  ----------  ----------  ------------
 owner-services-dev        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-prod        ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test1       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test2       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
owner-services-test3       ✗           ✗           ✗            ✗           ✗           ✗            ✗            ✗           ✗            ✗
 sales-services-dev        ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-prod        ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test1       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test2       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
sales-services-test3       ✓           ✓           ✓            ✓           ✓           ✓            ✓            ✓           ✓            ✓
```
(добавилось чтение секретов в продуктовой и dev-среде своего домена)

#### dora
```bash
uv run python3 ./test_permissions.py --kubeconfig=users/kubeconfig_dora
```
В конце должно выдать:
```
     Namespace         CM Create    CM Read    Sec Create    Sec List    Sec Read    Pod List    Pod Create    Pod Logs    Svc List    Svc Create
--------------------  -----------  ---------  ------------  ----------  ----------  ----------  ------------  ----------  ----------  ------------
 owner-services-dev        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
owner-services-prod        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
owner-services-test1       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
owner-services-test2       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
owner-services-test3       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✗           ✓            ✗
 sales-services-dev        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✓           ✓            ✗
sales-services-prod        ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✓           ✓            ✗
sales-services-test1       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✓           ✓            ✗
sales-services-test2       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✓           ✓            ✗
sales-services-test3       ✗           ✓           ✗            ✗           ✗           ✓            ✗            ✓           ✓            ✗
```
(т.е. умеет читать все пространства и все ресурчы, кроме секретов)