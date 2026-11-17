#!/usr/bin/env bash
# Instala o tema e a configuração do seletor de boot (Grubz/rEFInd) e tira o 2o menu do GRUB.
# Uso: sudo bash instalar.sh            (desfazer: sudo bash desfazer.sh)
# Opcional: ESP_UBUNTU=<PARTUUID> ESP_WINDOWS=<PARTUUID> sudo -E bash instalar.sh
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Rode com sudo." >&2; exit 1; }
AQUI="$(cd "$(dirname "$0")" && pwd)"
ESP=/boot/efi/EFI/grubz
BK="$AQUI/backup"
TIPO_ESP=c12a7328-f81f-11d2-ba4b-00a0c93ec93b

mountpoint -q /boot/efi || { echo "/boot/efi não está montada." >&2; exit 1; }
[[ -f $ESP/grubx64.efi && -f $ESP/shimx64.efi ]] || { echo "Grubz não encontrado em $ESP (veja Requisitos no README)." >&2; exit 1; }
for f in refind.conf theme/ubuntu.png theme/windows.png theme/selection.png theme/background.png; do
  [[ -s $AQUI/$f ]] || { echo "Falta $AQUI/$f" >&2; exit 1; }
done

echo "== 0/4 Partições EFI"
ESP_UBUNTU=${ESP_UBUNTU:-$(findmnt -no PARTUUID /boot/efi)}
if [[ -z ${ESP_WINDOWS:-} ]]; then
  mapfile -t OUTRAS < <(lsblk -rno PARTUUID,PARTTYPE | awk -v t=$TIPO_ESP -v u="$ESP_UBUNTU" '$2==t && $1!=u {print $1}')
  [[ ${#OUTRAS[@]} -eq 1 ]] || { echo "Achei ${#OUTRAS[@]} outras partições EFI; informe ESP_WINDOWS=<PARTUUID>." >&2; exit 1; }
  ESP_WINDOWS=${OUTRAS[0]}
fi
echo "Ubuntu: $ESP_UBUNTU   Windows: $ESP_WINDOWS"

echo "== 1/4 Backup (só na 1a vez) em $BK"
if [[ ! -d $BK/grubz ]]; then
  mkdir -p "$BK"
  cp -a "$ESP" "$BK/grubz"
  efibootmgr -v > "$BK/efibootmgr.txt"
  [[ -f /etc/default/grub.d/50-grubz.cfg ]] && cp -a /etc/default/grub.d/50-grubz.cfg "$BK/" || true
  chown -R "${SUDO_USER:-root}:" "$BK"
fi

echo "== 2/4 Tema e configuração na partição EFI"
sed -e "s/@ESP_UBUNTU@/$ESP_UBUNTU/" -e "s/@ESP_WINDOWS@/$ESP_WINDOWS/" "$AQUI/refind.conf" > "$ESP/refind.conf.novo"
for f in ubuntu windows selection background; do
  install -m 0755 "$AQUI/theme/$f.png" "$ESP/theme/$f.png.novo"
done
mv -f "$ESP/refind.conf.novo" "$ESP/refind.conf"
for f in ubuntu windows selection background; do mv -f "$ESP/theme/$f.png.novo" "$ESP/theme/$f.png"; done
rm -f "$ESP/theme/debian.png" "$ESP/refind.log"
sync

echo "== 3/4 GRUB do Ubuntu sem 2o menu (quem escolhe o sistema é o seletor)"
cat > /etc/default/grub.d/50-grubz.cfg <<'CFG'
# Instalado pelo Tela-Boot (instalar.sh): o seletor Grubz já escolhe o sistema,
# então o GRUB não procura o Windows e entra direto no Ubuntu.
GRUB_DISABLE_OS_PROBER=true
GRUB_TIMEOUT=0
GRUB_TIMEOUT_STYLE=hidden
CFG
if ! update-grub; then
  echo "update-grub falhou: voltando a config do GRUB." >&2
  rm -f /etc/default/grub.d/50-grubz.cfg; update-grub || true; exit 1
fi

echo "== 4/4 Manter o shim do seletor igual ao do Ubuntu nas atualizações"
cat > /etc/apt/apt.conf.d/99grubz-shim <<'APT'
// Instalado pelo Tela-Boot (instalar.sh): copia o shim/MokManager novos do Ubuntu para o seletor Grubz.
DPkg::Post-Invoke { "if [ -d /boot/efi/EFI/grubz ]; then for f in shimx64.efi mmx64.efi; do [ -f /boot/efi/EFI/ubuntu/$f ] && ! cmp -s /boot/efi/EFI/ubuntu/$f /boot/efi/EFI/grubz/$f && cp /boot/efi/EFI/ubuntu/$f /boot/efi/EFI/grubz/$f; done; fi; true"; };
APT

G=$(efibootmgr | sed -n 's/^Boot\([0-9A-Fa-f]\{4\}\)\*\? \+Grubz.*/\1/p' | head -1)
ORD=$(efibootmgr | sed -n 's/^BootOrder: //p')
if [[ -n $G && ${ORD%%,*} != "$G" ]]; then
  efibootmgr -o "$G,$(echo "$ORD" | tr ',' '\n' | grep -vx "$G" | paste -sd,)" >/dev/null
fi
echo
echo "PRONTO. BootOrder: $(efibootmgr | sed -n 's/^BootOrder: //p') (Grubz = Boot${G:-?})"
echo "Ao ligar: Ubuntu e Windows lado a lado; setas + Enter. Sem escolha em 10 s -> Ubuntu."
echo "Se der problema: F12 no logo da Dell abre o menu da placa; desfazer: sudo bash $AQUI/desfazer.sh"
