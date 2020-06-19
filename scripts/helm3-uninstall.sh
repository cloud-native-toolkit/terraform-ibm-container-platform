#!/usr/bin/env bash

RELEASE_NAME="$1"
NAMESPACE="$2"

SECRET_NAME=$(kubectl get secret --namespace "${NAMESPACE}" -o=custom-columns=name:.metadata.name | grep -E "sh.helm.release.*ibmcloud-config")
kubectl delete "secret/${SECRET_NAME}" --namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null
kubectl delete configmap/ibmcloud-config -namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null
kubectl delete secret/ibmcloud-apikey --namespace "${NAMESPACE}" 1> /dev/null 2> /dev/null

exit 0
