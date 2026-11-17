#!/usr/bin/env bash
# Volta o seletor e o GRUB para como estavam antes do instalar.sh.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Rode com sudo." >&2; exit 1; }
AQUI="$(cd "$(dirname "$0")" && pwd)"; BK="$AQUI/backup"; ESP=/boot/efi/EFI/grubz
[[ -d $BK/grubz ]] || { echo "Sem backup em $BK." >&2; exit 1; }
cp -a "$BK/grubz/refind.conf" "$ESP/refind.conf"
rm -rf "$ESP/theme"; cp -a "$BK/grubz/theme" "$ESP/theme"
if [[ -f $BK/50-grubz.cfg ]]; then cp -a "$BK/50-grubz.cfg" /etc/default/grub.d/; else rm -f /etc/default/grub.d/50-grubz.cfg; fi
rm -f /etc/apt/apt.conf.d/99grubz-shim
update-grub
sync
echo "Desfeito. (O Grubz continua instalado; para tirá-lo da ordem de boot: sudo efibootmgr -o <Ubuntu>,<Grubz>,...)"
