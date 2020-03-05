#!/usr/bin/env bash

# Copyright 2020 The Jetstack cert-manager contributors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o nounset
set -o errexit
set -o pipefail

LIB_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" > /dev/null && pwd )"
export REPO_ROOT="$LIB_ROOT/../.."

export SKIP_BUILD_ADDON_IMAGES="${SKIP_BUILD_ADDON_IMAGES:-}"
export KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-kind}"

# setup_tools will build and set up the environment to use bazel-provided
# versions of the tools required for development
setup_tools() {
  check_bazel
  bazel build //hack/bin:helm //hack/bin:kind //hack/bin:kubectl //devel/bin:ginkgo
  local bindir="$(bazel info bazel-genfiles)"
  export HELM="${bindir}/hack/bin/helm"
  export KIND="${bindir}/hack/bin/kind"
  export KUBECTL="${bindir}/hack/bin/kubectl"
  export GINKGO="${bindir}/devel/bin/ginkgo"
  # Configure PATH to use bazel provided e2e tools
  export PATH="${SCRIPT_ROOT}/bin:$PATH"
}

# check_tool ensures that the tool with the given name is available, or advises
# users to setup their PATH for the test/e3e/bin directory if not.
check_tool() {
  tool="$1"
  if ! command -v "$tool" &>/dev/null; then
    echo "Install $tool or run: export PATH=\"$REPO_ROOT/devel/bin:\$PATH\"" >&2
    exit 1
  fi
}

# check_bazel ensures that bazel is installed/available.
check_bazel() {
  if ! command -v bazel &>/dev/null; then
    echo "Install bazel at https://bazel.build" >&2
    exit 1
  fi
}

# require_image will attempt to ensure that the named docker image exists
# within the kind cluster with name $KIND_CLUSTER_NAME.
# If $SKIP_BUILD_ADDON_IMAGES is 'true', the image will not be built and a
# warning message will be printed instead.
require_image() {
  IMAGE_NAME="$1"
  BAZEL_TARGET="$2"
  # Skip building and loading the image if SKIP_BUILD_ADDON_IMAGES=true
  if [ "${SKIP_BUILD_ADDON_IMAGES:-}" == "true" ]; then
    echo "Skipping building and loading image '$IMAGE_NAME' because SKIP_BUILD_ADDON_IMAGES=true"
    return
  fi

  # Ensure bazel is available
  check_bazel
  # Ensure kind is available
  check_tool kind

  # Build and export the docker image
  bazel run --platforms=@io_bazel_rules_go//go/toolchain:linux_amd64 "${BAZEL_TARGET}"

  # Load the image into the kind cluster
  kind load docker-image --name "$KIND_CLUSTER_NAME" "$IMAGE_NAME"
}