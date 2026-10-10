#!/bin/bash
DriftWM + Noctalia Installer
Для: CachyOS / Arch Linux
Совместимость: SDDM, GDM, LightDM, ly, greetd

set -euo pipefail
─────────────────────────────────────
Цвета и форматирование
─────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

ok() { echo -e " GREEN✓GREEN✓{NC} $1"; }
warn() { echo -e " YELLOW⚠YELLOW⚠{NC} $1"; }
err() { echo -e " RED✗RED✗{NC} $1"; }
info() { echo -e " BLUE→BLUE→{NC} $1"; }

header() {
echo ""
echo -e "${BOLD}[$1/$TOTAL_STEPS] 22{NC}"
echo "─────────────────────────────────────"
}

TOTAL_STEPS=5
CONFIG_FILE="$HOME/.config/driftwm/config.toml"
SESSION_FILE="/usr/share/wayland-sessions/driftwm.desktop"
BUILD_DIR=""
─────────────────────────────────────
Очистка при ошибке или прерывании
─────────────────────────────────────

cleanup() {
if [ -n "$BUILD_DIR" ] && [ -d "$BUILD_DIR" ]; then
rm -rf "$BUILD_DIR"
warn "Временные файлы сборки удалены"
fi
}
trap cleanup EXIT ERR INT TERM
─────────────────────────────────────
Баннер
─────────────────────────────────────

echo ""
echo -e "BOLD╔════════════════════════════════════╗BOLD╔════════════════════════════════════╗{NC}"
echo -e "BOLD║DriftWM+NoctaliaInstaller║BOLD║DriftWM+NoctaliaInstaller║{NC}"
echo -e "BOLD╚════════════════════════════════════╝BOLD╚════════════════════════════════════╝{NC}"
─────────────────────────────────────
0) Предварительные проверки
─────────────────────────────────────

echo ""
echo -e "BOLDПроверяемсистему...BOLDПроверяемсистему...{NC}"
Не root

if [ "$EUID" -eq 0 ]; then
err "Не запускай от root! yay/paru этого не любят."
echo " Запусти заново как обычный пользователь."
exit 1
fi
ok "Не root"
Arch-based

if ! command -v pacman &> /dev/null; then
err "pacman не найден. Скрипт только для Arch-based дистрибутивов."
exit 1
fi
ok "Arch-based система"
AUR-хелпер

AUR_HELPER=""
for helper in yay paru; do
if command -v "$helper" &> /dev/null; then
AUR_HELPER="$helper"
break
fi
done

if [ -z "$AUR_HELPER" ]; then
err "Не найден yay или paru."
echo " Установи: sudo pacman -S yay"
exit 1
fi
ok "AUR-хелпер: {BOLD}$AUR_HELPER{NC}"
Интернет

if ! ping -c 1 -W 3 archlinux.org &> /dev/null; then
err "Нет интернета. Проверь подключение."
exit 1
fi
ok "Интернет доступен"
Необходимые утилиты

for cmd in git curl; do
if ! command -v "$cmd" &> /dev/null; then
err "$cmd не установлен. Ставим..."
sudo pacman -S --noconfirm "$cmd"
fi
done
ok "git, curl на месте"
─────────────────────────────────────
1) DriftWM
─────────────────────────────────────

header 1 "DriftWM"

if command -v driftwm &> /dev/null; then
ok "DriftWM уже установлен — пропускаем"
else
info "Устанавливаем driftwm-git из AUR..."
$AUR_HELPER -S --noconfirm --needed driftwm-git
ok "DriftWM установлен"
fi
Конфиг

mkdir -p ~/.config/driftwm

if [ -f "$CONFIG_FILE" ]; then
ok "Конфиг уже существует — не трогаем"
elif [ -f /etc/driftwm/config.reference.toml ]; then
cp /etc/driftwm/config.reference.toml "$CONFIG_FILE"
ok "Конфиг скопирован из /etc/"
else
curl -sfL https://raw.githubusercontent.com/malbiruk/driftwm/main/extras/config.reference.toml
-o "$CONFIG_FILE"
if [ -s "$CONFIG_FILE" ]; then
ok "Конфиг скачан с GitHub"
else
err "Не удалось скачать конфиг"
rm -f "$CONFIG_FILE"
exit 1
fi
fi
─────────────────────────────────────
2) Зависимости для noctalia-qs
─────────────────────────────────────

header 2 "Зависимости noctalia-qs"

DEPS=(
git base-devel cmake ninja
qt6-base qt6-declarative qt6-wayland
wayland wayland-protocols pipewire
libxkbcommon wl-clipboard
)

info "Проверяем и доставляем {#DEPS[@]} пакетов..." sudo pacman -S --needed --noconfirm "{DEPS[@]}"
ok "Все зависимости на месте"
─────────────────────────────────────
3) noctalia-qs
─────────────────────────────────────

header 3 "noctalia-qs (Quickshell)"

if command -v qs &> /dev/null; then
ok "qs уже установлен — пропускаем"
else
info "Собираем noctalia-qs из исходников..."

text

BUILD_DIR=$(mktemp -d /tmp/noctalia-build.XXXXXX)
git clone --depth 1 https://github.com/linuxmobile/noctalia-qs.git "$BUILD_DIR/noctalia-qs"

cd "$BUILD_DIR/noctalia-qs"
cmake -GNinja -B build \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DCMAKE_INSTALL_PREFIX=/usr/local
cmake --build build
sudo cmake --install build
cd "$HOME"

rm -rf "$BUILD_DIR"
BUILD_DIR=""

if command -v qs &> /dev/null; then
    ok "noctalia-qs собран и установлен"
else
    err "Сборка завершилась, но 'qs' не найден в PATH"
    warn "Попробуй: export PATH=\$PATH:/usr/local/bin"
    exit 1
fi

fi
─────────────────────────────────────
4) driftwm-noctalia (shell)
─────────────────────────────────────

header 4 "driftwm-noctalia (Shell)"

SHELL_DIR="$HOME/.config/quickshell/noctalia-shell"
mkdir -p ~/.config/quickshell

if [ -d "$SHELL_DIR" ]; then
info "Папка уже есть — обновляем..."
git -C "$SHELL_DIR" pull --ff-only 2>/dev/null || warn "git pull не удался (возможно, локальные изменения)"
ok "driftwm-noctalia обновлён"
else
git clone https://github.com/youssefvdel/driftwm-noctalia.git "$SHELL_DIR"
ok "driftwm-noctalia установлен"
fi
─────────────────────────────────────
5) Финальная настройка
─────────────────────────────────────

header 5 "Финальная настройка"
--- Автозапуск Noctalia ---

if grep -q "noctalia-shell" "$CONFIG_FILE" 2>/dev/null; then
ok "Автозапуск Noctalia уже прописан"
else
if grep -qE "^autostart\s*=" "$CONFIG_FILE" 2>/dev/null; then
sed -i 's/^autostart\s*=\s*[/autostart = ["qs -c noctalia-shell", /' "$CONFIG_FILE"
else
printf '\nautostart = ["qs -c noctalia-shell"]\n' >> "$CONFIG_FILE"
fi
ok "Автозапуск Noctalia добавлен в конфиг"
fi
--- .desktop сессия ---

if [ -f "$SESSION_FILE" ]; then
ok "Файл сессии уже существует"
else
info "Создаём файл сессии..."
sudo tee "$SESSION_FILE" > /dev/null << 'EOF'
[Desktop Entry]
Name=DriftWM
Comment=Infinite canvas Wayland compositor
Exec=driftwm
Type=Application
DesktopNames=DriftWM
EOF
ok "Сессия создана: $SESSION_FILE"
fi
--- Определяем DM ---

DM="не определён"
DM_HINT=""

declare -A DM_NAMES=(
[sddm]="SDDM"
[gdm]="GDM"
[lightdm]="LightDM"
[ly]="ly"
[greetd]="greetd"
)

for service in "{!DM_NAMES[@]}"; do if systemctl is-active --quiet "$service" 2>/dev/null; then DM="{DM_NAMES[$service]}"
case "$service" in
ly) DM_HINT="В ly: нажми F2 или ←→ для выбора сессии" ;;
greetd) DM_HINT="В greetd/tuigreet: выбери DriftWM из списка" ;;
sddm) DM_HINT="В SDDM: нажми на выпадающий список сессий" ;;
*) DM_HINT="" ;;
esac
break
fi
done
─────────────────────────────────────
Итог
─────────────────────────────────────

echo ""
echo -e "BOLD╔════════════════════════════════════╗BOLD╔════════════════════════════════════╗{NC}"
echo -e "${BOLD}║ GREEN✓Всёустановлено!GREEN✓Всёустановлено!{NC}BOLD║BOLD║{NC}"
echo -e "BOLD╚════════════════════════════════════╝BOLD╚════════════════════════════════════╝{NC}"
echo ""
echo -e " Менеджер входа: {BOLD}$DM{NC}"
echo ""
echo -e " BOLDЧтоделать:BOLDЧтоделать:{NC}"
echo " 1. Выйди из сессии (logout)"
echo " 2. Выбери сессию «DriftWM»"
[ -n "$DM_HINT" ] && echo -e " {YELLOW}$DM_HINT{NC}"
echo " 3. Залогинься и тестируй!"
echo ""
echo -e " BOLDПолноеудаление:BOLDПолноеудаление:{NC}"
echo " $AUR_HELPER -Rns driftwm-git"
echo " sudo rm -f $SESSION_FILE"
echo " rm -rf ~/.config/driftwm ~/.config/quickshell/noctalia-shell"
echo " sudo pacman -Rns $(pacman -Qdtq) 2>/dev/null"
echo ""
