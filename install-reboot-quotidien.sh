#!/bin/bash
# Installe (ou retire) un reboot quotidien à 4h du matin.
# Usage : ./install-reboot-quotidien.sh [install|uninstall|status] [--force]

CRON_FILE="/etc/cron.d/reboot-quotidien"
LOG="/var/log/reboot-quotidien.log"
START_SCRIPT="/home/xtreamcodes/iptv_xtream_codes/start_services.sh"
HEURE="4"
ACTION="${1:-install}"
FORCE="$2"

if [ "$(id -u)" -ne 0 ]; then
  echo "Lancez ce script en root."; exit 1
fi

case "$ACTION" in
  uninstall)
    rm -f "$CRON_FILE"
    echo "Reboot quotidien désactivé."
    exit 0 ;;
  status)
    if [ -f "$CRON_FILE" ]; then echo "ACTIF :"; cat "$CRON_FILE"; else echo "Non installé."; fi
    echo "Fuseau horaire : $(timedatectl | grep 'Time zone')"
    exit 0 ;;
  install) ;;
  *) echo "Usage : $0 [install|uninstall|status] [--force]"; exit 1 ;;
esac

ERREURS=0
echo "=== Vérifications avant installation ==="

# 1. Erreurs disque depuis le dernier démarrage
if dmesg 2>/dev/null | grep -qE "I/O error|hard resetting link|NCQ disabled|blk_update_request"; then
  echo "[ERREUR] Le noyau signale des erreurs disque :"
  dmesg -T | grep -E "I/O error|hard resetting link|NCQ disabled" | tail -5
  ERREURS=1
else
  echo "[OK] Aucune erreur disque dans dmesg"
fi

# 2. RAID dégradé
if [ -f /proc/mdstat ] && grep -qE "\[[U_]*_[U_]*\]" /proc/mdstat; then
  echo "[ERREUR] Un RAID est dégradé (voir /proc/mdstat)"
  ERREURS=1
else
  echo "[OK] RAID sans signe de dégradation"
fi

# 3. Montage de /home persistant (fstab) si /home est un point de montage séparé
if findmnt -n /home >/dev/null 2>&1; then
  if grep -qE "[[:space:]]/home[[:space:]]" /etc/fstab; then
    echo "[OK] /home est dans /etc/fstab"
  else
    echo "[ERREUR] /home est monté mais absent de /etc/fstab : il ne remontera pas au reboot"
    ERREURS=1
  fi
fi

# 4. Assemblage RAID au boot
if [ -f /proc/mdstat ] && grep -q "^md" /proc/mdstat; then
  if grep -q "^ARRAY" /etc/mdadm/mdadm.conf 2>/dev/null; then
    echo "[OK] RAID déclaré dans /etc/mdadm/mdadm.conf"
  else
    echo "[ERREUR] RAID absent de /etc/mdadm/mdadm.conf (faire : mdadm --detail --scan >> /etc/mdadm/mdadm.conf puis update-initramfs -u)"
    ERREURS=1
  fi
fi

if [ "$ERREURS" -eq 1 ] && [ "$FORCE" != "--force" ]; then
  echo
  echo "Installation annulée : corrigez les points ci-dessus (ou --force, à vos risques)."
  exit 1
fi

# 5. XtreamCodes redémarre-t-il seul au boot ?
AUTOSTART=0
if grep -rqs "start_services" /etc/crontab /etc/cron.d /etc/rc.local 2>/dev/null \
   || crontab -l 2>/dev/null | grep -q "start_services"; then
  AUTOSTART=1
  echo "[OK] start_services.sh est déjà lancé au démarrage"
else
  echo "[INFO] Aucun démarrage automatique de XtreamCodes détecté : ajout d'un @reboot"
fi

# Écriture de la tâche cron
{
  echo "SHELL=/bin/bash"
  echo "PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
  echo "0 $HEURE * * * root echo \"\$(date '+\\%F \\%T') reboot planifié\" >> $LOG; /sbin/shutdown -r now \"Reboot quotidien\""
  if [ "$AUTOSTART" -eq 0 ] && [ -x "$START_SCRIPT" ]; then
    echo "@reboot root sleep 60 && $START_SCRIPT >> $LOG 2>&1"
  fi
} > "$CRON_FILE"
chmod 644 "$CRON_FILE"

echo
echo "=== Installé ==="
cat "$CRON_FILE"
echo
echo "Fuseau horaire du serveur : $(timedatectl | grep 'Time zone')"
echo "Le reboot aura lieu à ${HEURE}h dans ce fuseau."
echo "Journal : $LOG"
