# Задание 5. Управление трафиком

```bash
bash setup_minikube_sh
```

```bash
bash create_backend_services.sh
```

И проверяем, что соединения между "фронтэнд-сервисами" и "бэкэнд-сервисами" работают без ограничений (нужно ждать 40 секунд, кошерные условия ожидания я не настраивал):
```bash
bash check_connections.sh
```
Здесь создаются временные поды с метками `app=frontend,role=frontend` и `app=admin-frontend,role=admin-frontend`
и каждый из них по очереди пытается подключиться к `backend-headless` и `admin-backend-headless`. А затем печатаем результат (`hello backend` и `hello admin backend`). Вывод должен быть таким (все 4 подключения успешны):

```
===========================
check-conn-frontend-calls-backend
pod/check-conn-frontend-calls-backend created
hello backend
pod "check-conn-frontend-calls-backend" deleted
===========================
check-conn-frontend-calls-admin-backend
pod/check-conn-frontend-calls-admin-backend created
hello admin backend
pod "check-conn-frontend-calls-admin-backend" deleted
===========================
check-conn-admin-frontend-calls-backend
pod/check-conn-admin-frontend-calls-backend created
hello backend
pod "check-conn-admin-frontend-calls-backend" deleted
===========================
check-conn-admin-frontend-calls-admin-backend
pod/check-conn-admin-frontend-calls-admin-backend created
hello admin backend
pod "check-conn-admin-frontend-calls-admin-backend" deleted
```

Теперь включаем наши network policy, которые отключат нам лишние подключения, оставив только подключения между `backend -- frontend` и `backend-admin -- frontend-admin`:
```bash
kubectl apply -f network-policy.yaml -n network-policy-sandbox
```
И проверим, что станет с подключениями между "фронтэндами" и "бэкэндами" (ждать ещё 40 секунд):
```bash
bash check_connections.sh
```

Вывод должен быть таким:
```
===========================
check-conn-frontend-calls-backend
pod/check-conn-frontend-calls-backend created
hello backend
pod "check-conn-frontend-calls-backend" deleted
===========================
check-conn-frontend-calls-admin-backend
pod/check-conn-frontend-calls-admin-backend created
wget: download timed out
pod "check-conn-frontend-calls-admin-backend" deleted
===========================
check-conn-admin-frontend-calls-backend
pod/check-conn-admin-frontend-calls-backend created
wget: download timed out
pod "check-conn-admin-frontend-calls-backend" deleted
===========================
check-conn-admin-frontend-calls-admin-backend
pod/check-conn-admin-frontend-calls-admin-backend created
hello admin backend
pod "check-conn-admin-frontend-calls-admin-backend" deleted
```

Т.е. на разрешённых парах бэкэнд-фронтэнд ответ будет прежний, `hello backend` и `hello admin backend`, а на запрещённых будет `wget: download timed out`. 