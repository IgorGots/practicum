#!/bin/bash

# set -e

# if ! command -v jq &>/dev/null; then
#   echo "jq could not be found, please install it https://stedolan.github.io/jq/manual/" >&2
#   exit 1
# fi

IAM_TOKEN=`yc iam create-token`
YC_CLOUD_ID=$(terraform output -raw cloud_id)
YC_FOLDER_ID=$(terraform output -raw folder_id)

# curl -s -H "Authorization: Bearer ${IAM_TOKEN}" \
#     "https://compute.api.cloud.yandex.net/compute/v1/images?\
# folderId=standard-images&pageSize=1&filter=FAMILY=\"gitlab\"&order_by=createdAt%20desc" # > output.json


YC_PROFILE=${YC_PROFILE:-default}
# if [ -z "$YC_CLOUD_ID" ]; then
#   echo "Env variable YC_CLOUD_ID is required" >&2
#   exit 1
# fi

function run_yc() {
  yc --profile "$YC_PROFILE" --format json "$@"
}

for folder in "charts" "values"; do
    if [ ! -d folder ]; then
        mkdir folder
    fi
done

# Первым делом установим ArgoCD внутри созданного на прошлом уроке кластера.
if [ ! -d "charts/argo-cd" ]; then
    export HELM_EXPERIMENTAL_OCI=1 && \
    helm pull oci://cr.yandex/yc-marketplace/yandex-cloud/argo/chart/argo-cd \
    --version=4.5.3-1 \
    --untar \
    --untardir=charts
fi

# Gitlab password
echo "GITLAB ip:   $(terraform output -raw gitlab_nat_ip)"
echo "GITLAB user: root"
ssh -o StrictHostKeyChecking=no ubuntu@$(terraform output -raw gitlab_nat_ip) 'sudo cat /etc/gitlab/initial_root_password | grep Password:'
# https://docs.gitlab.com/ee/api/oauth2.html#resource-owner-password-credentials-flow
# curl --data "grant_type=password&username=root&password=9RFKfwKcOKqoomS+DOWvk/0gbmws3vlNiawEzGvKs1U=" --request POST "http://158.160.97.246/oauth/token"

yc --folder-id=$YC_FOLDER_ID managed-kubernetes cluster get-credentials --name=practicum-folder-kubecluster --external --force

echo "HELM"
kubectl delete namespace argocd
helm install --replace -n argocd --create-namespace argocd charts/argo-cd

echo "ARGOCD user: admin"
echo "ARGOCD pass: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo)"

sleep 10
kubectl port-forward svc/argocd-server -n argocd 8080:443