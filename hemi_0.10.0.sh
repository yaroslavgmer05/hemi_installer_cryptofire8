#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # Сброс цвета

# Функция для установки ноды
install_node() {
    echo -e "${CYAN}Начинается установка ноды Hemi...${NC}"
    
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl tar -y

    # Загрузка и распаковка бинарников
    curl -L -O https://github.com/hemilabs/heminetwork/releases/download/v0.11.2/heminetwork_v0.11.2_linux_amd64.tar.gz
    mkdir -p ~/hemi && tar --strip-components=1 -xzvf heminetwork_v0.11.2_linux_amd64.tar.gz -C ~/hemi

    # Запрос на создание или ввод приватного ключа
    echo -e "${YELLOW}Вы хотите создать новый приватный ключ или использовать существующий?${NC}"
    echo -e "${CYAN}1) Создать новый ключ${NC}"
    echo -e "${CYAN}2) Ввести свой ключ${NC}"
    read -p "Выберите вариант (1/2): " key_choice

    if [ "$key_choice" == "1" ]; then
        ~/hemi/keygen -secp256k1 -json -net="testnet" > ~/popm-address.json
        PRIV_KEY=$(jq -r '.privkey' ~/popm-address.json)
        echo -e "${RED}Ваш приватный ключ: $PRIV_KEY${NC}"
    else
        read -p "Введите ваш приватный ключ: " PRIV_KEY
    fi

    # Запрос значения комиссии
    read -p "Введите размер комиссии (не менее 50): " FEE

    # Сохранение переменных окружения
    echo "POPM_BTC_PRIVKEY=$PRIV_KEY" > ~/hemi/popmd.env
    echo "POPM_STATIC_FEE=$FEE" >> ~/hemi/popmd.env
    echo "POPM_BFG_URL=wss://testnet.rpc.hemi.network/v1/ws/public" >> ~/hemi/popmd.env

    # Создание systemd-сервиса
    cat <<EOT | sudo tee /etc/systemd/system/hemi.service > /dev/null
[Unit]
Description=Hemi Node Service
After=network.target

[Service]
User=$USER
EnvironmentFile=$HOME/hemi/popmd.env
ExecStart=$HOME/hemi/popmd
WorkingDirectory=$HOME/hemi
Restart=always

[Install]
WantedBy=multi-user.target
EOT

    # Запуск сервиса
    sudo systemctl daemon-reload
    sudo systemctl enable hemi
    sudo systemctl start hemi

    echo -e "${GREEN}Нода Hemi успешно установлена и запущена!${NC}"
    echo -e "${YELLOW}Просмотр логов: sudo journalctl -u hemi -f${NC}"
}

# Функция для проверки приватного ключа
check_private_key() {
    if [ -f ~/hemi/popmd.env ]; then
        PRIV_KEY=$(grep "POPM_BTC_PRIVKEY" ~/hemi/popmd.env | cut -d '=' -f2)
        echo -e "${GREEN}Ваш приватный ключ: $PRIV_KEY${NC}"
    else
        echo -e "${RED}Файл конфигурации не найден!${NC}"
    fi
}

# Функция для изменения комиссии
change_fee() {
    if [ -f ~/hemi/popmd.env ]; then
        read -p "Введите новую комиссию (не менее 50): " NEW_FEE
        sed -i "s/^POPM_STATIC_FEE=.*/POPM_STATIC_FEE=$NEW_FEE/" ~/hemi/popmd.env
        sudo systemctl restart hemi
        echo -e "${GREEN}Комиссия обновлена!${NC}"
    else
        echo -e "${RED}Файл конфигурации не найден!${NC}"
    fi
}

# Функция для проверки логов
check_logs() {
    sudo journalctl -u hemi -f
}

# Функция для удаления ноды
uninstall_node() {
    echo -e "${RED}Удаление ноды Hemi...${NC}"
    sudo systemctl stop hemi
    sudo systemctl disable hemi
    sudo rm -f /etc/systemd/system/hemi.service
    sudo rm -rf ~/hemi
    sudo systemctl daemon-reload
    echo -e "${GREEN}Нода Hemi полностью удалена!${NC}"
}

# Главное меню
while true; do
    echo -e "${CYAN}Добро пожаловать в установщик ноды Hemi!${NC}"
    echo -e "${YELLOW}Выберите действие:${NC}"
    echo -e "${CYAN}1) Установка ноды Hemi${NC}"
    echo -e "${CYAN}2) Проверка приватного ключа${NC}"
    echo -e "${CYAN}3) Изменение комиссии${NC}"
    echo -e "${CYAN}4) Проверка логов${NC}"
    echo -e "${CYAN}5) Удаление ноды${NC}"
    echo -e "${CYAN}6) Выход${NC}"
    
    read -p "Введите номер действия: " choice

    case $choice in
        1) install_node ;;
        2) check_private_key ;;
        3) change_fee ;;
        4) check_logs ;;
        5) uninstall_node ;;
        6) echo -e "${GREEN}Выход из скрипта.${NC}"; exit 0 ;;
        *) echo -e "${RED}Некорректный ввод, попробуйте снова.${NC}" ;;
    esac
done
