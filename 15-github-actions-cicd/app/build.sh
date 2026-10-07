#!/usr/bin/env bash
# Packages the app into dist/ - this is the "build output" the pipeline uploads as an artifact.
set -euo pipefail

VERSION="${APP_VERSION:-local}"
rm -rf dist
mkdir -p dist/devops-s16-app
cp -r src requirements.txt dist/devops-s16-app/
find dist -name '__pycache__' -prune -exec rm -rf {} +

cat > dist/devops-s16-app/build-info.txt <<INFO
Application: devops-s16-app
Version: ${VERSION}
Commit: ${GITHUB_SHA:-local}
Build Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
INFO

tar -czf "dist/devops-s16-app-${VERSION}.tar.gz" -C dist devops-s16-app
echo "Build output:"
ls -la dist
cat dist/devops-s16-app/build-info.txt
