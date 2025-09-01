# Задание 4. Защита доступа к кластеру Kubernetes


## Роли для namespace

| Роль  | Права роли | Группы пользователей |
| --- | --- | --- |
| `app-viewer` | get/list/watch ресурсов в namespace, просмотр логов | `{team}-developers` |
| `app-deployer` | управление Deployments/ReplicaSets/StatefulSets/Jobs/CRs, чтение ConfigMap, создание/обновление Secrets (без чтения) | `{team}-devops` |
| `config-editor` | создание и редактирование ConfigMap (без чтения секретов) | `{team}-devops` |
| `secret-reader` | чтение секретов в namespace | `{team}-devops` (минимально) |
| `maintenance` | rollout restart, scale, create jobs | `{team}-managers` |
| `namespace-admin` | полный контроль внутри namespace | `{team}-devops` (lead dev/owner) |

## Кластерные роли

| Роль  | Права роли | Группы пользователей |
| --- | --- | --- |
| `cluster-viewer` | просмотр всех namespaces для аудита | `security-group` |
| `cluster-maintainer` | управление глобальными ресурсами: storageclasses, CRDs | `platform-admins` |
| `ingress-admin` | управление ингрессами и сервисами, включая load balancer'ы | `{team}-devops` |
| `storage-admin` | создание/удаление PV, управление CSI | `platform-admins` |


## Группы пользователей

- `platform-admins`: имеют полный доступ к кластеру (в будущем заменить на ограниченный `cluster-admin`)
- `{team}-devops`: девопсы каждой продуктовой команды, имеют высокие права, включая управление сервисами, хранилищами, бэкапом;
- `{team}-developers`: девопсы каждой продуктовой команды, имеют доступ на просмотр состояний и чтение логов сервисов; 
- `{team}-managers`: это операционная команда каждой продуктовой команды (менеджеры), имеют доступ к админ-панелям сервисов, но внутрь Kubernetes не ходят;
- `security-group`: специалисты ИБ, имеют доступ на чтение логов во всех пространствах для аудита безопасности (секреты читать не могут).