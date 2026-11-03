# Конфигурация виртуальной машины devops-vm

## 1. Параметры машины
- Оперативная память: 2048 МБ
- Количество ядер процессора: 2
- Объём дискового накопителя: 25 ГБ (динамически расширяемый)

## 2. Сетевые интерфейсы
- **Адаптер 1 (NAT):**
  - Интерфейс: `enp0s3`
  - IP-адрес: `10.0.2.15/24`
  - Назначение: доступ к репозиториям пакетов и интернету.
- **Адаптер 2 (Host-only):**
  - Интерфейс: `enp0s8`
  - IP-адрес: `192.168.56.106/24`
  - Назначение: доступ с хостовой системы (Windows) к веб-серверу и SSH.

## 3. Правило проброса портов
- Порт хостовой системы: `2222`
- Порт гостевой системы: `2222`
- Протокол: `TCP`

## 4. Учётные записи
- **student:** входит в группу `sudo`. Аутентификация по паролю.
- **devops:** входит в группу `sudo`. Аутентификация по SSH-ключу (`devops_vm`), парольная аутентификация отключена.

## 5. Служба SSH
- Порт: `2222`
- Расположение файла конфигурации: `/etc/ssh/sshd_config.d/99-hardening.conf`
- Изменённые директивы и их значения:
  - `Port 2222`
  - `PermitRootLogin no`
  - `PasswordAuthentication no`
  - `PubkeyAuthentication yes`
  - `PermitEmptyPasswords no`
  - `MaxAuthTries 3`
  - `LoginGraceTime 30`
  - `AllowUsers devops`
  - `X11Forwarding no`
  - `ClientAliveInterval 300`
  - `ClientAliveCountMax 2`

## 6. Правила межсетевого экрана
- **Политики по умолчанию:** `deny incoming`, `allow outgoing`.
- **Перечень правил:**
  - `2222/tcp` — LIMIT (SSH rate-limited)
  - `80/tcp` — ALLOW (HTTP)
  - `443/tcp` — ALLOW (HTTPS)

## 7. Снимки состояния
- `01-clean-install` — создан сразу после установки ОС (чистая система).
- `02-keys-configured` — создан после настройки SSH-ключей для пользователя `devops`.
- `03-ssh-hardened` — создан после усиления защиты SSH (смена порта, отключение паролей).

## 8. Веб-сервер
- **Устанавливаемый пакет:** `nginx`
- **Путь к конфигурации ресурса:** `/etc/nginx/sites-available/devops-site` (активирована символической ссылкой в `/etc/nginx/sites-enabled/`)
- **Каталог ресурса:** `/var/www/devops-site`
- **Владелец каталога:** `devops:devops`
- **Права на каталоги и файлы:** 755 (drwxr-xr-x) для каталогов, 644 (-rw-r--r--) для файлов.
- **Путь к сертификату:** `/etc/ssl/certs/devops.crt` (права 644, владелец root)
- **Путь к ключу:** `/etc/ssl/private/devops.key` (права 600, владелец root)
- **Команда формирования сертификата:**
  ```bash
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/devops.key \
    -out /etc/ssl/certs/devops.crt \
    -subj "/CN=devops.local" \
    -addext "subjectAltName=DNS:devops.local"
  ```
- **Срок действия сертификата:** 365 дней.