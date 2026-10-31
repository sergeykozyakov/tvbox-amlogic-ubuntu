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

echo "=== 1. Принудительно подключаем драйвер Panfrost для графической библиотеки Mesa ==="

cat << 'EOT' > /etc/profile.d/wayland-mali-gpu.sh
export GALLIUM_DRIVER=panfrost
export MESA_LOADER_DRIVER_OVERRIDE=panfrost
export GBM_BACKEND=panfrost
export XDG_SESSION_TYPE=wayland
export EGL_PLATFORM=wayland
export MESA_GL_VERSION_OVERRIDE=3.3
export MESA_GLES_VERSION_OVERRIDE=3.1
EOT

chmod +x /etc/profile.d/wayland-mali-gpu.sh

echo "=== 2. Переводим Chromium на нативный Wayland и ускорение GPU ==="

mkdir -p /etc/chromium-browser/
cat << 'EOT' > /etc/chromium-browser/default
CHROMIUM_FLAGS="--ignore-gpu-blocklist --enable-gpu-rasterization --enable-zero-copy --ozone-platform-hint=auto --ozone-platform=wayland --enable-features=UseOzonePlatform --disable-software-rasterizer --num-raster-threads=2"
EOT

echo "=== 3. Оптимизируем лимиты памяти для устранения утечек ==="

LIMITS_FILE="/etc/security/limits.conf"

sed -i '/memlock/d' "$LIMITS_FILE"

sed -i '/^# End of file/i \
*               soft    memlock         unlimited\n\
*               hard    memlock         unlimited' "$LIMITS_FILE"

echo "=== 4. Настройка конфигурации Happ ==="
HAPP_CONFIG="${HOME}/.config/Happ.conf"

update_conf_param() {
    local key=$1
    local value=$2
    local file=$3

    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    else
        sed -i "/^\[Preferences\]/a ${key}=${value}" "$file"
    fi
}

update_conf_param "graphicsBackend" "Software" "$HAPP_CONFIG"
update_conf_param "platformPlugin" "Wayland" "$HAPP_CONFIG"

echo "=== 5. Настройка завершена! ==="

read -p "Для активации аппаратного ускорения, перезагрузите приставку, нажав [Enter]..."
    
sleep 3
reboot
