#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

minikube delete

# Если вы сидите на Ubuntu и хотите запускать minikube c driver=docker:
# To avoid this error: https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

# Создаем временную директорию для монтирования
TEMP_DIR=$(mktemp -d)
cp $BASEDIR/audit-policy.yaml $TEMP_DIR/

echo "Запускаем minikube с audit логированием..."
# Используем mount для передачи файлов и упрощенные настройки audit
minikube start --driver=docker --cpus=4 --memory=16g --disk-size=40g \
  --mount --mount-string="$TEMP_DIR:/tmp/audit" \
  --extra-config=apiserver.audit-log-path=/tmp/audit/audit.log \
  --extra-config=apiserver.audit-policy-file=/tmp/audit/audit-policy.yaml \
  --extra-config=apiserver.audit-log-maxage=1 \
  --extra-config=apiserver.audit-log-maxbackup=1 \
  --extra-config=apiserver.audit-log-maxsize=10

echo "Ждем запуска API server..."
sleep 30

# Копируем логи обратно на хост для просмотра
echo "Настраиваем доступ к audit логам..."
minikube ssh "sudo chmod 644 /tmp/audit/audit.log 2>/dev/null || true"

echo "Audit логи будут доступны в: $TEMP_DIR/audit.log"
echo "Для просмотра логов используйте: tail -f $TEMP_DIR/audit.log"

minikube addons enable metrics-server
# To avoid PVC errors
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

echo "Проверяем статус minikube:"
minikube status