#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install gatekeeper gatekeeper/gatekeeper -n gatekeeper-system --create-namespace

# И пространство для Constraint'ов OPA Gatekeeper
kubectl create namespace opa-gatekeeper-specs

# 1. ConstraintTemplate создается ГЛОБАЛЬНО
kubectl apply -f $BASEDIR/constraint-template.yaml

# 2. Небольшая пауза для создания CRD
sleep 5

# 3. Применить Constraint
kubectl apply -f $BASEDIR/constraint.yaml

# 4. Проверить статус (constraint тоже может быть глобальным)
echo "=== Статус Constraint ==="
kubectl get podsecuritypolicy
kubectl describe podsecuritypolicy secure-pods-policy