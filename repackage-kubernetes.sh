#!/usr/bin/env bash
# Create the resources for the Canonical Distribution of Kubernetes.

# The first argument ($1) should be the Kubernetes version.

# NOTE The kubernetes-worker resource depends on a CNI resource loopback which
# is created in the repackage-flannel.sh script.

set -o errexit  # Exit when an individual command fails.
set -o pipefail  # The exit status of the last command is returned.
#set -o xtrace  # Print the commands that are executed.

echo "${0} started at `date`."

SCRIPT_DIR=${PWD}

# Get the function definitions for os and architecture detection.
source ./utilities.sh
# Get the versions of the software to package.
source ./versions.sh

ARCH=${ARCH:-"amd64"}
OS=${OS:-"linux"}

# Create a url to the Kubernetes release archive.
KUBE_URL=https://github.com/kubernetes/kubernetes/releases/download/${KUBE_VERSION}/kubernetes.tar.gz
KUBE_ARCHIVE=${TEMPORARY_DIRECTORY}/kubernetes.tar.gz
download ${KUBE_URL} ${KUBE_ARCHIVE}
echo "Compare this hash to https://github.com/kubernetes/kubernetes/releases"
echo ""
echo "Uncompressing ${KUBE_ARCHIVE}"
tar -xvzf ${KUBE_ARCHIVE} -C ${TEMPORARY_DIRECTORY}
KUBE_ROOT=${TEMPORARY_DIRECTORY}/kubernetes

export KUBERNETES_SKIP_CONFIRM=Y
export KUBERNETES_DOWNLOAD_TESTS=Y
# Use the upstream utility for downloading the server binaries.
${KUBE_ROOT}/cluster/get-kube-binaries.sh

# TODO Figure out how to download server binaries for each architecture.

E2E_DIRECTORY=${KUBE_ROOT}/platforms/${OS}/${ARCH}
E2E_ARCHIVE=${SCRIPT_DIR}/e2e-${KUBE_VERSION}-${ARCH}.tar.gz
echo "Creating the ${E2E_ARCHIVE} file."
E2E_FILES="kubectl ginkgo e2e.test e2e_node.test"
create_archive ${E2E_DIRECTORY} ${E2E_ARCHIVE} "${E2E_FILES}"

SERVER_FILE=${KUBE_ROOT}/server/kubernetes-server-${OS}-${ARCH}.tar.gz
# If the server file does not exist the get-kube-binaries.sh did not work.
if [[ ! -e ${SERVER_FILE} ]]; then
  echo "${SERVER_FILE} does not exist!" >&2
  exit 3
fi
# Print out the size and sha256 hash sum of the server file.
echo "$(ls -hl ${SERVER_FILE} | cut -d ' ' -f 5) $(basename ${SERVER_FILE})"
echo "$(sha256sum_file ${SERVER_FILE}) $(basename ${SERVER_FILE})"

# Expand the server file archive to get the master binaries.
tar -xvzf ${SERVER_FILE} -C ${TEMPORARY_DIRECTORY}
# The server directory is where the master and worker binaries are kept.
SERVER_DIRECTORY=${KUBE_ROOT}/server/bin

MASTER_ARCHIVE=${SCRIPT_DIR}/kubernetes-master-${KUBE_VERSION}-${ARCH}.tar.gz
echo "Creating the ${MASTER_ARCHIVE} file."
MASTER_FILES="kube-apiserver kube-controller-manager kubectl kube-scheduler"
create_archive ${SERVER_DIRECTORY} ${MASTER_ARCHIVE} "${MASTER_FILES}"

# Copy the loopback binary (needed for CNI) to the server directory.
cp -v ${TEMPORARY_DIRECTORY}/${OS}/${ARCH}/loopback ${SERVER_DIRECTORY}/
WORKER_ARCHIVE=${SCRIPT_DIR}/kubernetes-worker-${KUBE_VERSION}-${ARCH}.tar.gz
echo "Creating the ${WORKER_ARCHIVE} file."
# NOTE The loopback binary is from the CNI project, see repackage-flannel.sh
WORKER_FILES="kubectl kubelet kube-proxy loopback"
create_archive ${SERVER_DIRECTORY} ${WORKER_ARCHIVE} "${WORKER_FILES}"

cd ${SCRIPT_DIR}
echo "${0} completed successfully at `date`."
