#!/usr/bin/env bash
# tune-xtream-phpfpm.sh
# Applique le réglage PHP-FPM (ondemand) pour de nombreux viewers sur Xtream Codes.
#
# Usage :
#   ./tune-xtream-phpfpm.sh [--children N] [--restart] [--dry-run]
#   ./tune-xtream-phpfpm.sh --rollback
#
# Options :
#   --children N   valeur de pm.max_children (défaut : 2500, pour ~2000 viewers)
#   --restart      relance les services Xtream Codes à la fin (coupe les viewers)
#   --dry-run      affiche ce qui serait fait, sans rien modifier
#   --rollback     restaure la dernière sauvegarde des fichiers .conf
#
# Le script est idempotent : on peut le relancer sans créer de doublons.

set -u

XC_DIR="${XC_DIR:-/home/xtreamcodes/iptv_xtream_codes}"
PHP_ETC="$XC_DIR/php/etc"
PHP_FPM_BIN="$XC_DIR/php/sbin/php-fpm"
NGINX_CONF="$XC_DIR/nginx/conf/nginx.conf"
BACKUP_ROOT="/root/backup-phpfpm"

MAX_CHILDREN=2500
IDLE_TIMEOUT="10s"
BACKLOG=4096
RLIMIT_FILES=65535
DO_RESTART=0
DRY_RUN=0
ROLLBACK=0

log()  { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }
fail() { printf '[ERREUR] %s\n' "$*" >&2; exit 1; }

# ---------- arguments ----------
while [ $# -gt 0 ]; do
  case "$1" in
    --children) shift; MAX_CHILDREN="${1:-}";;
    --restart)  DO_RESTART=1;;
    --dry-run)  DRY_RUN=1;;
    --rollback) ROLLBACK=1;;
    -h|--help)  sed -n '2,16p' "$0"; exit 0;;
    *) fail "Option inconnue : $1";;
  esac
  shift
done

case "$MAX_CHILDREN" in
  ''|*[!0-9]*) fail "--children doit être un nombre entier";;
esac

[ "$(id -u)" -eq 0 ] || fail "À lancer en root."
[ -d "$PHP_ETC" ]    || fail "Dossier introuvable : $PHP_ETC (définis XC_DIR si l'installation est ailleurs)"
[ -x "$PHP_FPM_BIN" ] || fail "php-fpm introuvable : $PHP_FPM_BIN"

restart_services() {
  if [ -x "$XC_DIR/start_services.sh" ]; then
    log "Redémarrage via start_services.sh (les viewers seront coupés quelques secondes)..."
    "$XC_DIR/start_services.sh"
  elif command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files 2>/dev/null | grep -q '^xtreamcodes'; then
    log "Redémarrage via systemctl..."
    systemctl restart xtreamcodes
  else
    log "Aucune commande de redémarrage trouvée : relance Xtream Codes manuellement."
  fi
}

# ---------- rollback ----------
if [ "$ROLLBACK" -eq 1 ]; then
  LAST="$(ls -1dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -n1)"
  [ -n "$LAST" ] || fail "Aucune sauvegarde dans $BACKUP_ROOT"
  log "Restauration depuis $LAST"
  cp -a "$LAST"/*.conf "$PHP_ETC"/ || fail "Échec de la restauration"
  log "Fichiers restaurés. Relance Xtream Codes pour appliquer."
  [ "$DO_RESTART" -eq 1 ] && restart_services
  exit 0
fi

# ---------- fichiers de pool à modifier ----------
# On ne touche que les .conf qui définissent un pool (ligne "pm = ...").
POOL_FILES=()
for f in "$PHP_ETC"/*.conf; do
  [ -f "$f" ] || continue
  grep -qE '^[[:space:]]*pm[[:space:]]*=' "$f" && POOL_FILES+=("$f")
done
[ "${#POOL_FILES[@]}" -gt 0 ] || fail "Aucun fichier de pool (avec 'pm =') trouvé dans $PHP_ETC"

log "Pools détectés : ${#POOL_FILES[@]}"
for f in "${POOL_FILES[@]}"; do log "  - $(basename "$f")"; done
log "Cible : ondemand, pm.max_children=$MAX_CHILDREN, idle_timeout=$IDLE_TIMEOUT, backlog=$BACKLOG, rlimit_files=$RLIMIT_FILES"

if [ "$DRY_RUN" -eq 1 ]; then
  log "Mode --dry-run : rien n'est modifié."
  exit 0
fi

# ---------- sauvegarde ----------
BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR" || fail "Impossible de créer $BACKUP_DIR"
cp -a "${POOL_FILES[@]}" "$BACKUP_DIR"/ || fail "Échec de la sauvegarde"
log "Sauvegarde : $BACKUP_DIR"

# ---------- remplace la directive si elle existe, sinon l'ajoute ----------
set_key() {
  local file="$1" key="$2" value="$3" esc
  esc="$(printf '%s' "$key" | sed 's/\./\\./g')"
  if grep -qE "^[[:space:]]*${esc}[[:space:]]*=" "$file"; then
    sed -i -E "s|^[[:space:]]*${esc}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    sed -i -e '$a\' "$file"          # garantit un retour à la ligne final
    printf '%s = %s\n' "$key" "$value" >> "$file"
  fi
}

restore_and_exit() {
  log "Échec : restauration de la sauvegarde."
  cp -a "$BACKUP_DIR"/*.conf "$PHP_ETC"/
  fail "$1"
}

for f in "${POOL_FILES[@]}"; do
  set_key "$f" "pm" "ondemand"
  set_key "$f" "pm.max_children" "$MAX_CHILDREN"
  set_key "$f" "pm.process_idle_timeout" "$IDLE_TIMEOUT"
  set_key "$f" "listen.backlog" "$BACKLOG"
  set_key "$f" "rlimit_files" "$RLIMIT_FILES"
  # pm.max_requests : on le règle à 500 seulement s'il est absent
  grep -qE '^[[:space:]]*pm\.max_requests[[:space:]]*=' "$f" || set_key "$f" "pm.max_requests" "500"
done

# ---------- validation ----------
for f in "${POOL_FILES[@]}"; do
  out="$("$PHP_FPM_BIN" -t -y "$f" 2>&1)" || restore_and_exit "Test de syntaxe échoué pour $(basename "$f") : $out"
  log "Syntaxe OK : $(basename "$f")"
  # détecte les directives dupliquées
  for k in pm pm.max_children pm.process_idle_timeout listen.backlog rlimit_files pm.max_requests; do
    n="$(grep -cE "^[[:space:]]*$(printf '%s' "$k" | sed 's/\./\\./g')[[:space:]]*=" "$f")"
    [ "$n" -le 1 ] || restore_and_exit "Directive '$k' en double dans $(basename "$f")"
  done
done

# ---------- limites système (fichiers dédiés, idempotents) ----------
cat > /etc/security/limits.d/99-xtream.conf <<EOF
* soft nofile $RLIMIT_FILES
* hard nofile $RLIMIT_FILES
root soft nofile $RLIMIT_FILES
root hard nofile $RLIMIT_FILES
EOF
cat > /etc/sysctl.d/99-xtream.conf <<EOF
net.core.somaxconn = $BACKLOG
net.ipv4.ip_local_port_range = 1024 65535
EOF
sysctl --system >/dev/null 2>&1 && log "Limites système appliquées (limits.d + sysctl.d)"

# ---------- contrôle nginx (information uniquement) ----------
if [ -f "$NGINX_CONF" ]; then
  log "nginx : $(grep -hE 'worker_rlimit_nofile|worker_connections' "$NGINX_CONF" | tr -s ' ' | tr '\n' ' ')"
  log "        (recommandé : worker_rlimit_nofile >= 65535 et worker_connections >= 8192)"
fi

# ---------- redémarrage ----------
if [ "$DO_RESTART" -eq 1 ]; then
  restart_services
  sleep 5
  log "Limite de fichiers ouverts des maîtres PHP-FPM :"
  for p in $(pgrep -f 'php-fpm: master'); do grep 'open files' "/proc/$p/limits"; done
else
  log "Config écrite mais PAS encore active. Relance avec --restart ou redémarre Xtream Codes toi-même."
fi

log "Terminé. Retour arrière possible avec : $0 --rollback"
