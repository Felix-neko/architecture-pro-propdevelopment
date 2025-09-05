POD_NAME="check-conn-frontend-calls-backend"
echo "==========================="
echo $POD_NAME
#kubectl delete pod $POD_NAME -n network-policy-sandbox
kubectl run $POD_NAME -n network-policy-sandbox --restart=Never --labels='app=frontend,role=frontend' --image=alpine -- wget -qO- --timeout=2 http://backend-headless
sleep 10
kubectl logs -f $POD_NAME -n network-policy-sandbox
kubectl delete pod $POD_NAME -n network-policy-sandbox


POD_NAME="check-conn-frontend-calls-admin-backend"
echo "==========================="
echo $POD_NAME
#kubectl delete pod $POD_NAME -n network-policy-sandbox
kubectl run $POD_NAME -n network-policy-sandbox --restart=Never --labels='app=frontend,role=frontend' --image=alpine -- wget -qO- --timeout=2 http://admin-backend-headless
sleep 10
kubectl logs -f $POD_NAME -n network-policy-sandbox
kubectl delete pod $POD_NAME -n network-policy-sandbox


POD_NAME="check-conn-admin-frontend-calls-backend"
echo "==========================="
echo $POD_NAME
#kubectl delete pod $POD_NAME -n network-policy-sandbox
kubectl run $POD_NAME -n network-policy-sandbox --restart=Never --labels='app=admin-frontend,role=admin-frontend' --image=alpine -- wget -qO- --timeout=2 http://backend-headless
sleep 10
kubectl logs -f $POD_NAME -n network-policy-sandbox
kubectl delete pod $POD_NAME -n network-policy-sandbox


POD_NAME="check-conn-admin-frontend-calls-admin-backend"
echo "==========================="
echo $POD_NAME
#kubectl delete pod $POD_NAME -n network-policy-sandbox
kubectl run $POD_NAME -n network-policy-sandbox --restart=Never --labels='app=admin-frontend,role=admin-frontend' --image=alpine -- wget -qO- --timeout=2 http://admin-backend-headless
sleep 10
kubectl logs -f $POD_NAME -n network-policy-sandbox
kubectl delete pod $POD_NAME -n network-policy-sandbox