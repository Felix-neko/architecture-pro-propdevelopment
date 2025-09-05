#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

#kubectl delete -f $BASEDIR/insecure-manifests/00-nothing-special-pod.yaml -n insecure
#kubectl delete -f $BASEDIR/insecure-manifests/01-privileged-pod.yaml -n insecure
#kubectl delete -f $BASEDIR/insecure-manifests/02-hostpath-pod.yaml -n insecure
#kubectl delete -f $BASEDIR/insecure-manifests/03-root-user-pod.yaml -n insecure
#
#kubectl delete -f $BASEDIR/insecure-manifests/00-nothing-special-pod.yaml -n pod-security
#kubectl delete -f $BASEDIR/insecure-manifests/01-privileged-pod.yaml -n pod-security
#kubectl delete -f $BASEDIR/insecure-manifests/02-hostpath-pod.yaml -n pod-security
#kubectl delete -f $BASEDIR/insecure-manifests/03-root-user-pod.yaml -n pod-security

echo "=== Insecure ==="
kubectl apply -f $BASEDIR/insecure-manifests/00-nothing-special-pod.yaml -n insecure
kubectl apply -f $BASEDIR/insecure-manifests/01-privileged-pod.yaml -n insecure
kubectl apply -f $BASEDIR/insecure-manifests/02-hostpath-pod.yaml -n insecure
kubectl apply -f $BASEDIR/insecure-manifests/03-root-user-pod.yaml -n insecure

echo "=== PodSecurity ==="
kubectl apply -f $BASEDIR/insecure-manifests/00-nothing-special-pod.yaml -n pod-security
kubectl apply -f $BASEDIR/insecure-manifests/01-privileged-pod.yaml -n pod-security
kubectl apply -f $BASEDIR/insecure-manifests/02-hostpath-pod.yaml -n pod-security
kubectl apply -f $BASEDIR/insecure-manifests/03-root-user-pod.yaml -n pod-security

echo "=== OPA Gatekeeper ==="
kubectl apply -f $BASEDIR/insecure-manifests/00-nothing-special-pod.yaml -n opa-gatekeeper-controlled
kubectl apply -f $BASEDIR/insecure-manifests/01-privileged-pod.yaml -n opa-gatekeeper-controlled
kubectl apply -f $BASEDIR/insecure-manifests/02-hostpath-pod.yaml -n opa-gatekeeper-controlled
kubectl apply -f $BASEDIR/insecure-manifests/03-root-user-pod.yaml -n opa-gatekeeper-controlled