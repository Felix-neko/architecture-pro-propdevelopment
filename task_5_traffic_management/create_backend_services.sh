#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

kubectl create namespace network-policy-sandbox
kubectl apply -f $BASEDIR/backend-stateful-set.yaml -n network-policy-sandbox
