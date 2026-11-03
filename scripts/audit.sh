#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo " [OK] $desc"; ((PASS++))
    else
        echo " [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"
        ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$PORT" != "22" ]]; then
    echo " [OK] Порт SSH изменён (текущий: $PORT)"; ((PASS++))
else
    echo " [FAIL] Порт SSH остался стандартным (22)"; ((FAIL++))
fi

check "MaxAuthTries равно 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

DEFAULT_IN=$(sudo ufw status verbose | grep 'Default' | awk '{print $2}')
check "Политика по умолчанию для входящих - deny" "deny" "$DEFAULT_IN"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf " %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"

if sudo nginx -t >/dev/null 2>&1; then
    echo " [OK] Конфигурация nginx синтаксически корректна"; ((PASS++))
else
    echo " [FAIL] Конфигурация nginx содержит ошибки"; ((FAIL++))
fi

if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt >/dev/null 2>&1; then
    echo " [OK] Сертификат действителен более 30 дней"; ((PASS++))
else
    echo " [FAIL] Сертификат истекает менее чем через 30 дней"; ((FAIL++))
fi

NO_WRITABLE=$(find /var/www/devops-site -perm -o+w 2>/dev/null)
KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key)

if [[ -z "$NO_WRITABLE" ]]; then
    echo " [OK] В каталоге ресурса нет файлов с правом записи для всех"; ((PASS++))
else
    echo " [FAIL] Найдены файлы с правом записи для всех: $NO_WRITABLE"; ((FAIL++))
fi

check "Права ключа TLS равны 600" "600" "$KEY_PERMS"

echo "[5] Контейнеризация"
check "Служба docker активна" "active" "$(systemctl is-active docker)"

check "Контейнер СУБД healthy" "healthy" "$(sudo docker inspect -f '{{.State.Health.Status}}' app-db-1 2>/dev/null || echo 'not found')"

BAD_PORTS=$(sudo ss -tln | awk 'NR>1 {split($4, a, ":"); port=a[length(a)]; if ((port=="5000" || port=="5432") && $4 !~ /^127\.0\.0\.1:/) print $4}')
if [[ -z "$BAD_PORTS" ]]; then
    echo " [OK] Порты 5000 и 5432 не доступны извне"; ((PASS++))
else
    echo " [FAIL] Найдены открытые порты: $BAD_PORTS"; ((FAIL++))
fi

check "Права .env равны 600" "600" "$(stat -c '%a' ~/app/.env 2>/dev/null || echo 'not found')"

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1