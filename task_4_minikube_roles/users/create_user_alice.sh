#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

# Удаляем старые данные, если есть
kubectl delete csr alice-csr
rm -f alice.key alice.csr alice.crt ca.crt kubeconfig_alice

# Генерируем приватный ключ
openssl genrsa -out $BASEDIR/alice.key 2048

# CN=alice - Common Name (имя пользователя в Kubernetes)
# O=namespace-viewer -- техническая группа для просмотра списка namespace.
openssl req -new -key $BASEDIR/alice.key -out $BASEDIR/alice.csr -subj "/CN=alice/O=namespace-viewer"

# Кодируем CSR в base64 и подставляем в YAML
CSR_B64=$(cat $BASEDIR/alice.csr | base64 | tr -d '\n')
sed "s/\${CSR_B64}/$CSR_B64/g" $BASEDIR/user-alice.yaml | kubectl apply -f -

# Одобряем запрос на сертификат
kubectl certificate approve alice-csr

# Получаем подписанный сертификат
kubectl get csr alice-csr -o jsonpath='{.status.certificate}' | base64 --decode > $BASEDIR/alice.crt

# Создаем отдельный kubeconfig для alice
KUBECONFIG_ALICE=$BASEDIR/kubeconfig_alice

# Получаем информацию о текущем кластере
CURRENT_CONTEXT=$(kubectl config current-context)
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

# Получаем CA сертификат кластера
CA_CERT_PATH=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority}')
if [ -z "$CA_CERT_PATH" ]; then
    # Если CA в виде данных, извлекаем их
    kubectl config view --raw --minify --flatten -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 --decode > $BASEDIR/ca.crt
    CA_CERT_PATH=$BASEDIR/ca.crt
fi

# Создаем kubeconfig для alice
kubectl config --kubeconfig=$KUBECONFIG_ALICE set-cluster $CLUSTER_NAME --server=$CLUSTER_SERVER --certificate-authority=$CA_CERT_PATH --embed-certs=true
kubectl config --kubeconfig=$KUBECONFIG_ALICE set-credentials alice --client-certificate=$BASEDIR/alice.crt --client-key=$BASEDIR/alice.key --embed-certs=true
kubectl config --kubeconfig=$KUBECONFIG_ALICE set-context alice-context --cluster=$CLUSTER_NAME --user=alice
kubectl config --kubeconfig=$KUBECONFIG_ALICE use-context alice-context

echo "Kubeconfig для alice создан: $KUBECONFIG_ALICE"
echo "Для использования: export KUBECONFIG=$KUBECONFIG_ALICE"

