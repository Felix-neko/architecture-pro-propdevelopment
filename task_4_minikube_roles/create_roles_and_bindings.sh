#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

kubectl apply -f $BASEDIR/clusterrole-namespace-viewer.yaml
kubectl apply -f $BASEDIR/clusterrolebinding-namespace-viewer.yaml

kubectl apply -f $BASEDIR/clusterrole-cluster-viewer.yaml
kubectl apply -f $BASEDIR/clusterrolebinding-cluster-viewer.yaml

# Применяем роль sales-app-deployer в каждом sales namespace
kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n sales-services-prod
kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n sales-services-dev
kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n sales-services-test1
kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n sales-services-test2
kubectl apply -f $BASEDIR/role-sales-app-deployer.yaml -n sales-services-test3

# Применяем RoleBindings для sales-devops группы
kubectl apply -f $BASEDIR/rolebinding-sales-app-deployer.yaml