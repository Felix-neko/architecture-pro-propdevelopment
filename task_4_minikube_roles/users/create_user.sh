#!/usr/bin/env bash
BASEDIR=$(dirname "$0")

# Проверяем аргументы
if [ $# -lt 2 ]; then
    echo "Использование: $0 <username> <group1> [group2] [group3] ... [groupN]"
    echo "Пример: $0 anton namespace-viewer security-group"
    echo "Пример: $0 bruno sales-devops platform-admins"
    exit 1
fi

USERNAME=$1
shift # Убираем первый аргument (username), остальные - группы

# Собираем группы в массив (используем другое имя переменной)
USER_GROUPS=()
for arg in "$@"; do
    USER_GROUPS+=("$arg")
done

echo "Создание пользователя: $USERNAME"
echo "Количество групп: ${#USER_GROUPS[@]}"
echo "Группы: ${USER_GROUPS[*]}"

# Удаляем старые данные для этого пользователя, если есть
kubectl delete csr ${USERNAME}-csr 2>/dev/null || true
rm -f $BASEDIR/${USERNAME}.key $BASEDIR/${USERNAME}.csr $BASEDIR/${USERNAME}.crt $BASEDIR/ca.crt $BASEDIR/kubeconfig_${USERNAME}

# Генерируем приватный ключ
echo "Генерация приватного ключа..."
openssl genrsa -out $BASEDIR/${USERNAME}.key 2048

# Формируем subject строку с множественными группами
SUBJECT="/CN=${USERNAME}"
for group in "${USER_GROUPS[@]}"; do
    SUBJECT="${SUBJECT}/O=${group}"
done

echo "Subject для сертификата: $SUBJECT"

# Создаем CSR с множественными группами
openssl req -new -key $BASEDIR/${USERNAME}.key -out $BASEDIR/${USERNAME}.csr -subj "$SUBJECT"

# Создаем временный YAML для CSR
cat > $BASEDIR/user-${USERNAME}.yaml << EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}-csr
spec:
  request: \${CSR_B64}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
  - client auth
EOF

# Кодируем CSR в base64 и подставляем в YAML
echo "Создание CertificateSigningRequest..."
CSR_B64=$(cat $BASEDIR/${USERNAME}.csr | base64 | tr -d '\n')
sed "s/\${CSR_B64}/$CSR_B64/g" $BASEDIR/user-${USERNAME}.yaml | kubectl apply -f -

# Одобряем запрос на сертификат
echo "Одобрение сертификата..."
kubectl certificate approve ${USERNAME}-csr

# Получаем подписанный сертификат
echo "Получение подписанного сертификата..."
kubectl get csr ${USERNAME}-csr -o jsonpath='{.status.certificate}' | base64 --decode > $BASEDIR/${USERNAME}.crt

# Создаем отдельный kubeconfig для пользователя
KUBECONFIG_USER=$BASEDIR/kubeconfig_${USERNAME}

echo "Создание kubeconfig..."
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

# Создаем kubeconfig для пользователя
kubectl config --kubeconfig=$KUBECONFIG_USER set-cluster $CLUSTER_NAME --server=$CLUSTER_SERVER --certificate-authority=$CA_CERT_PATH --embed-certs=true
kubectl config --kubeconfig=$KUBECONFIG_USER set-credentials $USERNAME --client-certificate=$BASEDIR/${USERNAME}.crt --client-key=$BASEDIR/${USERNAME}.key --embed-certs=true
kubectl config --kubeconfig=$KUBECONFIG_USER set-context ${USERNAME}-context --cluster=$CLUSTER_NAME --user=$USERNAME
kubectl config --kubeconfig=$KUBECONFIG_USER use-context ${USERNAME}-context

# Очищаем временные файлы
rm -f $BASEDIR/user-${USERNAME}.yaml

echo ""
echo "✅ Пользователь $USERNAME успешно создан!"
echo "📁 Kubeconfig: $KUBECONFIG_USER"
echo "👥 Группы: ${USER_GROUPS[*]}"
echo ""
echo "Для использования:"
echo "export KUBECONFIG=$KUBECONFIG_USER"
echo "kubectl get pods # (если есть права)"
