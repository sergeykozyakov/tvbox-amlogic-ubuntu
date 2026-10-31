#!/bin/bash

if [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
    echo "ОШИБКА! Этот скрипт не может быть запущен вне графического окружения"
    exit 1
fi

if [[ "$USER" == "root" ]]; then
    echo "ОШИБКА! Этот скрипт не может выполняться напрямую от пользователя root"
    exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Пожалуйста, запустите скрипт с расширенными правами пользователя: sudo $0"
  exit 1
fi

echo "=== 1. Удаляем переменные окружения Panfrost ==="

if [[ -f /etc/profile.d/wayland-mali-gpu.sh ]]; then
  rm -f /etc/profile.d/wayland-mali-gpu.sh
  echo "Файл конфигурации Mesa удален"
else
  echo "Конфигурация Mesa не найдена, пропускаем"
fi

echo "=== 2. Сбрасываем флаги ускорения Chromium ==="

if [[ -f /etc/chromium-browser/default ]]; then
  rm -f /etc/chromium-browser/default
  echo "Флаги Chromium удалены"
else
  echo "Конфигурация Chromium не найдена, пропускаем"
fi

echo "=== 3. Восстанавливаем оригинальные лимиты памяти ==="

if [[ -f /etc/security/limits.conf ]]; then
  sed -i '/\*               soft    memlock         unlimited/d' /etc/security/limits.conf
  sed -i '/\*               hard    memlock         unlimited/d' /etc/security/limits.conf
  echo "Лимиты памяти в limits.conf возвращены к исходным"
fi

echo "=== 4. Сброс конфигурации Happ ==="

HAPP_CONFIG="$HOME/.config/Happ.conf"

reset_conf_param() {
    local key=$1
    local file=$2

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=Default|" "$file"
    fi
}

if [[ -f "$HAPP_CONFIG" ]]; then
    reset_conf_param "graphicsBackend" "$HAPP_CONFIG"
    reset_conf_param "platformPlugin" "$HAPP_CONFIG"
    echo "Параметры в Happ.conf успешно сброшены в Default."
else
    echo "Файл Happ.conf не найден, сброс параметров пропущен"
fi

echo "=== 5. Откат успешно завершен! ==="

read -p "Чтобы вернуть стандартные настройки графики, перезагрузите приставку, нажав [Enter]..."
    
sleep 3
reboot
