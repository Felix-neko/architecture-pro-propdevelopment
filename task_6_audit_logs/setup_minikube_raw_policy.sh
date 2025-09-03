#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

minikube delete

# Если вы сидите на Ubuntu и хотите запускать minikube c driver=docker:
# To avoid this error: https://kind.sigs.k8s.io/docs/user/known-issues/#pod-errors-due-to-too-many-open-files
sudo sysctl fs.inotify.max_user_watches=524288
sudo sysctl fs.inotify.max_user_instances=512

minikube stop

mkdir -p ~/.minikube/files/etc/ssl/certs

cp "$BASEDIR/audit-policy-raw.yaml" ~/.minikube/files/etc/ssl/certs/audit-policy-raw.yaml

minikube start --driver=docker --cpus=4 --memory=16g \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy-raw.yaml \
  --extra-config=apiserver.audit-log-path=-
#  --extra-config=apiserver.audit-log-path=/var/log/audit.log

minikube addons enable metrics-server
# To avoid PVC errors
minikube addons enable default-storageclass
minikube addons enable storage-provisioner

echo "Проверяем статус minikube:"
minikube status