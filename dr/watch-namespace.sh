#!/usr/bin/env bash
# Lets the Strimzi operator (installed in the namespace kafka) also watch another namespace: creates the
# namespace, adds it to STRIMZI_NAMESPACE of the operator and binds the operator's roles there.
# This is the procedure from the Strimzi documentation for "watch multiple namespaces".
#
#   ./watch-namespace.sh [namespace]      default: kafka-dr
. "$(dirname "$0")/../lib/common.sh"
need kubectl
ns="${1:-kafka-dr}"
OP=(-n "$KAFKA_NAMESPACE")
kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

current="$(kubectl "${OP[@]}" get deployment strimzi-cluster-operator -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="STRIMZI_NAMESPACE")].value}')"
case ",$current," in
  *",$ns,"*) echo "Operator already watches $ns." ;;
  *)
    # The release file sets STRIMZI_NAMESPACE from the pod's own namespace (a fieldRef); replace it by a list.
    kubectl "${OP[@]}" set env deployment/strimzi-cluster-operator "STRIMZI_NAMESPACE=${KAFKA_NAMESPACE},${ns}"
    kubectl "${OP[@]}" rollout status deployment/strimzi-cluster-operator --timeout=180s ;;
esac

sa="system:serviceaccount:${KAFKA_NAMESPACE}:strimzi-cluster-operator"
bind() { kubectl -n "$ns" create rolebinding "$1" --clusterrole="$2" --serviceaccount="${KAFKA_NAMESPACE}:strimzi-cluster-operator" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null; }
bind strimzi-cluster-operator strimzi-cluster-operator-namespaced
bind strimzi-cluster-operator-watched strimzi-cluster-operator-watched
bind strimzi-cluster-operator-entity-operator-delegation strimzi-entity-operator
echo "The operator watches ${KAFKA_NAMESPACE} and ${ns} (as ${sa})."
