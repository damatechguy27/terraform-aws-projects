#!/bin/bash
# EKS Node Bootstrap Script

# Bootstrap the node to join the EKS cluster
/etc/eks/bootstrap.sh ${CLUSTER_NAME} \
  --b64-cluster-ca ${CLUSTER_CA} \
  --apiserver-endpoint ${CLUSTER_ENDPOINT}
