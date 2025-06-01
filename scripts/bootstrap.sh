#!/bin/bash

echo -e "\n---Bootstrapping Kind Cluster---\n"


# check if cluster exists
if kind get clusters | grep -q "kind"; then
    echo "Cluster: 'kind' exists..."
else 
    kind create cluster --wait 5m --config=./kubernetes/kind-config.yaml
fi

echo -e "\n Downloading helm repos..."

# function to add helm repo
function add_helm_repo() {
    local name=$1
    local url=$2

    if helm repo list | grep -q "$name"; then
        echo "repo: $name already exists..."
    else
        echo "Adding repo: $name..."
        helm repo add $name $url
    fi
}


function helm_release(){
    local release=$1
    local namespace=${2:-default}
    helm status $release -n $namespace >/dev/null 2>&1
    return $?
}


# main repos
add_helm_repo traefik https://traefik.github.io/charts
add_helm_repo prometheus-community https://prometheus-community.github.io/helm-charts


# update helm repos
helm repo update


# Install Traefik with values
if ! helm_release traefik; then
    echo "Install: Traefik..."
    helm upgrade --install \
        traefik traefik/traefik \
        --values ./kubernetes/controllers/traefik/values.yaml \
        --wait
else
    echo "skipping: traefik already installed"
fi

# Install Prometheus Grafana for monitoring
if ! helm_release monitoring monitoring; then 
    echo "Install: kube-prom-stack..."
    helm upgrade --install \
        monitoring prometheus-community/kube-prometheus-stack \
        --namespace monitoring \
        --create-namespace \
        --values ./kubernetes/controllers/kube-prometheus/values.yaml
fi

# apply ingress, service & deployment
kubectl apply -f ./kubernetes/apps/app-deploy.yml
kubectl apply -f ./kubernetes/apps/ingress-app.yml