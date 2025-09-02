#!/usr/bin/env bash
# Скрипт для создания ролей и привязок RBAC в Kubernetes
# Применяет ClusterRoles, Roles и RoleBindings для различных групп пользователей

BASEDIR=$(dirname "$0")

echo "=== Применение ClusterRoles и ClusterRoleBindings ==="

# Применяем ClusterRole для просмотра namespace (базовые права)
echo "Применяем ClusterRole namespace-viewer..."
kubectl apply -f $BASEDIR/clusterrole-namespace-viewer.yaml

# Применяем ClusterRoleBinding для namespace-viewer
echo "Применяем ClusterRoleBinding namespace-viewer..."
kubectl apply -f $BASEDIR/clusterrolebinding-namespace-viewer.yaml

# Применяем ClusterRole для просмотра кластера (расширенные права)
echo "Применяем ClusterRole cluster-viewer..."
kubectl apply -f $BASEDIR/clusterrole-cluster-viewer.yaml

# Применяем ClusterRoleBinding для cluster-viewer
echo "Применяем ClusterRoleBinding cluster-viewer..."
kubectl apply -f $BASEDIR/clusterrolebinding-cluster-viewer.yaml

echo "=== Применение Roles в sales namespace ==="

# Список всех sales namespace для применения ролей
SALES_NAMESPACES=("sales-services-prod" "sales-services-dev" "sales-services-test1" "sales-services-test2" "sales-services-test3")

# Применяем роль sales-app-deployer в каждом sales namespace
echo "Применяем роль sales-app-deployer во всех sales namespace..."
for namespace in "${SALES_NAMESPACES[@]}"; do
    echo "  - Применяем в namespace: $namespace"
    kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n $namespace
done

# Применяем роль sales-config-editor в каждом sales namespace
echo "Применяем роль sales-config-editor во всех sales namespace..."
for namespace in "${SALES_NAMESPACES[@]}"; do
    echo "  - Применяем в namespace: $namespace"
    kubectl apply -f $BASEDIR/role-sales-config-editor.yaml -n $namespace
done

# Применяем роль sales-test-secrets-reader только в тестовых namespace
echo "Применяем роль sales-test-secrets-reader в тестовых namespace..."
TEST_NAMESPACES=("sales-services-test1" "sales-services-test2" "sales-services-test3")
for namespace in "${TEST_NAMESPACES[@]}"; do
    echo "  - Применяем в namespace: $namespace"
    kubectl apply -f $BASEDIR/role-sales-test-secrets-reader.yaml -n $namespace
done

# Применяем роль sales-secrets-reader во всех sales namespace
echo "Применяем роль sales-secrets-reader во всех sales namespace..."
for namespace in "${SALES_NAMESPACES[@]}"; do
    echo "  - Применяем в namespace: $namespace"
    kubectl apply -f $BASEDIR/role-sales-secrets-reader.yaml -n $namespace
done

# Применяем роль sales-app-viewer во всех sales namespace
echo "Применяем роль sales-app-viewer во всех sales namespace..."
for namespace in "${SALES_NAMESPACES[@]}"; do
    echo "  - Применяем в namespace: $namespace"
    kubectl apply -f $BASEDIR/role-sales-app-viewer.yaml -n $namespace
done

echo "=== Применение RoleBindings ==="

# Применяем объединенные RoleBindings для sales-devops группы
# Включает привязки для ролей: sales-app-deployer, sales-config-editor, sales-test-secrets-reader
echo "Применяем объединенные RoleBindings для sales-devops группы..."
echo "  - Включает роли: sales-app-deployer, sales-config-editor, sales-test-secrets-reader"
kubectl apply -f $BASEDIR/rolebinding-sales-devops.yaml

# Применяем RoleBindings для sales-lead-devops группы (secrets-reader)
echo "Применяем RoleBindings для sales-lead-devops группы..."
for namespace in "${SALES_NAMESPACES[@]}"; do
    echo "  - Применяем sales-lead-devops binding в namespace: $namespace"
    kubectl apply -f $BASEDIR/rolebinding-sales-lead-devops.yaml -n $namespace
done

# Применяем RoleBindings для sales-developers группы (app-viewer)
echo "Применяем RoleBindings для sales-developers группы..."
echo "  - Включает роль: sales-app-viewer (права только на чтение)"
kubectl apply -f $BASEDIR/rolebinding-sales-developers.yaml

echo "=== Завершено ==="
echo "Все роли и привязки успешно применены!"