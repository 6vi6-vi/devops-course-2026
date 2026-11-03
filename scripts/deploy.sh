#!/usr/bin/env bash

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site"

RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=5 -o IdentitiesOnly=yes"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

echo "=== Начало деплоя ==="

if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "ОШИБКА: Файл site/index.html отсутствует. Деплой отменен." >&2
    exit 1
fi

if ! git diff-index --quiet HEAD --; then
    echo "ОШИБКА: В репозитории есть незафиксированные изменения. Закоммитьте их или отмените." >&2
    exit 1
fi

RSYNC_CMD=(rsync -avz --delete --chmod=D755,F644 -e "${RSYNC_SSH}")
if [[ "$DRY_RUN" == "true" ]]; then
    RSYNC_CMD+=("--dry-run")
    echo "--- Режим пробного запуска (Dry-run) ---"
fi

echo "Синхронизация ${LOCAL_DIR}/ -> ${REMOTE}:${REMOTE_DIR}..."
"${RSYNC_CMD[@]}" "${LOCAL_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

if [[ "$DRY_RUN" == "true" ]]; then
    echo "=== Пробный запуск завершен успешно ==="
    exit 0
fi

echo "Проверка доступности ${SITE_URL}..."
if ! curl -f -s --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "ОШИБКА: Ресурс ${SITE_URL} недоступен или сертификат не прошел проверку." >&2
    exit 1
fi

COMMIT_HASH=$(git rev-parse --short HEAD)
echo "=== Деплой успешно завершен! Доставлен коммит: ${COMMIT_HASH} ==="
exit 0