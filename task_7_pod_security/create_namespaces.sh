#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

kubectl create namespace insecure

# Пространство, контролируемое PodSecurity
kubectl create namespace pod-security

# Пространство, которое мы будем контролировать с помощью OPA Gatekeeper
kubectl create namespace opa-gatekeeper-controlled

