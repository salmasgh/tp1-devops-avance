#!/usr/bin/env bash
# Reproducible local k3s lab: folders, compose up, kubeconfig fix, node check.
set -euo pipefail
cd "$(dirname "$0")"

KUBECONFIG_FILE=kubeconfig/kubeconfig.yaml

mkdir -p work kubeconfig

docker compose up -d

echo "Waiting for $KUBECONFIG_FILE (max 120s)..."
for _ in $(seq 1 60); do
  [ -s "$KUBECONFIG_FILE" ] && break
  sleep 2
done
[ -s "$KUBECONFIG_FILE" ] || { echo "kubeconfig never appeared" >&2; docker compose logs k3s | tail -50; exit 1; }

# Portable in-place edit (GNU and BSD sed): write to a temp file, then move.
sed 's/127\.0\.0\.1/k3s/g' "$KUBECONFIG_FILE" > "$KUBECONFIG_FILE.tmp"
mv "$KUBECONFIG_FILE.tmp" "$KUBECONFIG_FILE"
chmod 666 "$KUBECONFIG_FILE" 2>/dev/null || true

echo "Waiting for node to be Ready (max 120s)..."
end=$((SECONDS + 120))
until docker exec toolbox kubectl get nodes 2>/dev/null | grep -qE '[[:space:]]Ready[[:space:]]'; do
  if [ "$SECONDS" -ge "$end" ]; then
    echo "Timed out waiting for node Ready" >&2
    docker compose logs k3s | tail -50
    exit 1
  fi
  sleep 3
done

docker compose ps
docker exec toolbox kubectl get nodes
