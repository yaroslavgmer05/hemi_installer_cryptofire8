#!/bin/bash

echo -e '\033[0;31m'
echo -e ' ███████╗██╗██████╗ ███████╗'
echo -e ' ██╔════╝██║██╔══██╗██╔════╝'
echo -e ' █████╗  ██║██████╔╝█████╗  '
echo -e ' ██╔══╝  ██║██╔══██╗██╔══╝  '
echo -e ' ██║     ██║██║  ██║███████╗'
echo -e ' ╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝'
echo -e '\033[0m'
echo -e "🔥 Подпишись на @cryptofire8 в Telegram [🚀]"
# Цвета текста
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Сброс цвета

# Функция для установки ноды
install_node() {
    echo -e "${CYAN}Начинаем установку ноды Hemi...${NC}"
    
    # Установка зависимостей
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl tar screen nano jq git unzip lz4

    # Загрузка и установка бинарников
    cd ~
    wget https://github.com/hemilabs/heminetwork/releases/download/v0.11.2/heminetwork_v0.11.2_linux_amd64.tar.gz
    mkdir -p ~/hemi
    tar --strip-components=1 -xzvf heminetwork_v0.11.2_linux_amd64.tar.gz -C ~/hemi
    rm heminetwork_v0.11.2_linux_amd64.tar.gz

    # Запрос приватного ключа и комиссии
    read -p "Введите ваш приватный ключ: " PRIV_KEY
    read -p "Введите размер комиссии (fee, минимум 50, по умолчанию 3000): " FEE
    FEE=${FEE:-3000}

    # Создание конфигурационного файла
    cat <<EOT > ~/hemi/popmd.env
POPM_BTC_PRIVKEY=$PRIV_KEY
POPM_STATIC_FEE=$FEE
POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public
EOT

    # Создание systemd-сервиса
    sudo tee /etc/systemd/system/hemid.service > /dev/null <<EOF
[Unit]
Description=Hemi Node Service
After=network.target

[Service]
User=$USER
EnvironmentFile=$HOME/hemi/popmd.env
ExecStart=$HOME/hemi/popmd
WorkingDirectory=$HOME/hemi
Restart=always
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    # Запуск сервиса
    sudo systemctl daemon-reload
    sudo systemctl enable hemid
    sudo systemctl start hemid

    echo -e "${GREEN}Нода Hemi успешно установлена и запущена!${NC}"
}

# Функция для изменения комиссии (fee)
change_fee() {
    if [ ! -f ~/hemi/popmd.env ]; then
        echo -e "${RED}Файл конфигурации не найден! Нода не установлена.${NC}"
        return
    fi

    read -p "Введите новую комиссию (fee, минимум 50): " NEW_FEE

    if [[ ! "$NEW_FEE" =~ ^[0-9]+$ ]] || [ "$NEW_FEE" -lt 50 ]; then
        echo -e "${RED}Ошибка! Введите корректное число (не менее 50).${NC}"
        return
    fi

    sed -i "s/^POPM_STATIC_FEE=.*/POPM_STATIC_FEE=$NEW_FEE/" ~/hemi/popmd.env

    sudo systemctl restart hemid
    echo -e "${GREEN}Комиссия обновлена до $NEW_FEE!${NC}"
}

# Функция для просмотра логов ноды
check_logs() {
    sudo journalctl -u hemid -f
}

# Функция для удаления ноды
uninstall_node() {
    echo -e "${RED}Удаление ноды Hemi...${NC}"
    sudo systemctl stop hemid
    sudo systemctl disable hemid
    sudo rm -f /etc/systemd/system/hemid.service
    sudo systemctl daemon-reload
    rm -rf ~/hemi
    echo -e "${GREEN}Нода полностью удалена!${NC}"
}

# Меню управления нодой
while true; do
    echo -e "${CYAN}Добро пожаловать в меню управления нодой Hemi!${NC}"
    echo -e "${YELLOW}Выберите действие:${NC}"
    echo -e "${CYAN}1) Установить ноду${NC}"
    echo -e "${CYAN}2) Изменить fee${NC}"
    echo -e "${CYAN}3) Просмотреть логи${NC}"
    echo -e "${CYAN}4) Удалить ноду${NC}"
    echo -e "${CYAN}5) Выйти${NC}"
    
    read -p "Введите номер действия: " choice

    case $choice in
        1) install_node ;;
        2) change_fee ;;
        3) check_logs ;;
        4) uninstall_node ;;
        5) echo -e "${GREEN}Выход из скрипта.${NC}"; exit 0 ;;
        *) echo -e "${RED}Некорректный ввод, попробуйте снова.${NC}" ;;
    esac
done
