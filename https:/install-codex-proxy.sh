#!/usr/bin/env bash
set -euo pipefail

PROXY_IP="195.133.21.100"
PROXY_PORT="1080"
PROXY_TYPE="socks5"

GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m"

echo -e "${GREEN}=== Zero One Codex Proxy Installer ===${NC}"
echo "Будет настроен запуск Codex только через SOCKS5-прокси:"
echo "${PROXY_IP}:${PROXY_PORT}"
echo

if [ "${EUID}" -ne 0 ]; then
  echo -e "${RED}Запусти от root:${NC}"
  echo "sudo bash install-codex-proxy.sh"
  exit 1
fi

echo -e "${YELLOW}1/5 Устанавливаю зависимости...${NC}"
apt update
apt install -y curl wget ca-certificates proxychains4

echo -e "${YELLOW}2/5 Настраиваю proxychains4...${NC}"

if [ -f /etc/proxychains4.conf ]; then
  cp /etc/proxychains4.conf "/etc/proxychains4.conf.bak.$(date +%s)"
fi

cat > /etc/proxychains4.conf <<EOF
strict_chain
quiet_mode
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
${PROXY_TYPE} ${PROXY_IP} ${PROXY_PORT}
EOF

echo -e "${YELLOW}3/5 Проверяю прокси...${NC}"

PROXY_CHECK="$(proxychains4 curl -s --connect-timeout 15 https://ifconfig.me || true)"

if [ -z "${PROXY_CHECK}" ]; then
  echo -e "${RED}Прокси не ответил.${NC}"
  echo "Проверь Dante на Timeweb и доступ с IP 81.163.56.122."
  exit 1
fi

echo "IP через прокси: ${PROXY_CHECK}"

echo -e "${YELLOW}4/5 Устанавливаю OpenAI Codex CLI через прокси...${NC}"

proxychains4 curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh

CODEX_BIN=""

if command -v codex >/dev/null 2>&1; then
  CODEX_BIN="$(command -v codex)"
elif [ -x "/root/.local/bin/codex" ]; then
  CODEX_BIN="/root/.local/bin/codex"
elif [ -x "${HOME}/.local/bin/codex" ]; then
  CODEX_BIN="${HOME}/.local/bin/codex"
else
  echo -e "${RED}Codex установлен, но бинарник codex не найден.${NC}"
  echo "Проверь вручную: find / -name codex 2>/dev/null | head"
  exit 1
fi

echo "Codex найден: ${CODEX_BIN}"

echo -e "${YELLOW}5/5 Создаю команду codex-proxy...${NC}"

cat > /usr/local/bin/codex-proxy <<EOF
#!/usr/bin/env bash
exec proxychains4 "${CODEX_BIN}" "\$@"
EOF

chmod +x /usr/local/bin/codex-proxy

echo
echo -e "${GREEN}Готово.${NC}"
echo
echo "Обычный Codex:"
echo "  codex"
echo
echo "Codex через Timeweb SOCKS5:"
echo "  codex-proxy"
echo
echo "Авторизация через прокси:"
echo "  codex-proxy login"
