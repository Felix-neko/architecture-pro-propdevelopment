#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

kubectl apply -f $BASEDIR/clusterrole-namespace-viewer.yaml
kubectl apply -f $BASEDIR/clusterrolebinding-namespace-viewer.yaml

kubectl apply -f $BASEDIR/clusterrole-cluster-viewer.yaml
kubectl apply -f $BASEDIR/clusterrolebinding-cluster-viewer.yaml