PortGuard

🇬🇧 PortGuard (English)

PortGuard shields your server from port scans using iptables + ipset.
Only your allowed ports stay open; scanners are auto-blacklisted (all ports look closed to them).

⚡️ Quick Install

sudo wget -qO /root/portguard.sh "https://raw.githubusercontent.com/wiijiitoolsecurite/PortGuard/main/secure_ports_scan.sh" \
sudo chmod +x /root/portguard.sh \
sudo /root/portguard.sh




🧭 Menu

1) Apply security (configure ports & thresholds)
2) Add IP to whitelist
3) Add IP to blacklist
4) Show whitelist & config
5) Show blacklist
0) Exit

Config at /etc/portguard.conf; persistence across reboots enabled.

✅ Requirements: Linux, root, iptables, ipset.




PortGuard protège votre serveur contre les scans de ports (iptables + ipset).
Il autorise uniquement les ports que vous déclarez et bannit automatiquement les scanneurs (pour eux, tous les ports paraissent fermés).
EN below.

⚡️ Installation rapide

sudo wget -qO /root/portguard.sh "https://raw.githubusercontent.com/wiijiitoolsecurite/PortGuard/main/secure_ports_scan.sh" \
sudo chmod +x /root/portguard.sh \
sudo /root/portguard.sh




🧭 Utilisation (menu)

1) Appliquer la sécurité (config ports & seuils)
2) Ajouter IP à la whitelist
3) Ajouter IP à la blacklist
4) Afficher whitelist & config
5) Afficher blacklist
0) Quitter

Config sauvegardée dans /etc/portguard.conf (modifiable à la main ou via l’option 1).

Persistance au reboot : ipset-restore.service + netfilter-persistent (ou service fallback auto).

✅ Prérequis

Linux (Debian/Ubuntu, RHEL/Alma/Rocky, openSUSE), root, iptables + ipset.



## install-reboot-quotidien.sh

Script qui installe, affiche ou désactive un **reboot quotidien** via cron (`/etc/cron.d/reboot-quotidien`). Lancé sans argument, il affiche le statut puis propose d'installer (si rien n'est installé) ou de désactiver (si c'est déjà actif).

### Installation

    wget -qO /root/install-reboot-quotidien.sh https://github.com/wiijiitoolsecurite/PortGuard/raw/refs/heads/main/install-reboot-quotidien.sh
    chmod +x /root/install-reboot-quotidien.sh
    /root/install-reboot-quotidien.sh

Ne pas le lancer avec `wget ... | bash` : le menu a besoin de lire votre réponse.

### Utilisation

    ./install-reboot-quotidien.sh            # statut + proposition d'action
    ./install-reboot-quotidien.sh status     # affiche le statut seulement
    ./install-reboot-quotidien.sh install    # installe (avec vérifications)
    ./install-reboot-quotidien.sh uninstall  # désactive

### Options

| Variable / option | Effet |
|---|---|
| `HEURE=2` | Heure du reboot, de 0 à 23 (défaut : 4), dans le fuseau du serveur |
| `START_SCRIPT=/chemin/script.sh` | Script lancé 60 s après chaque démarrage, si aucun démarrage automatique n'est détecté |
| `--force` | Installe malgré les erreurs détectées (déconseillé) |

Exemple : `HEURE=2 ./install-reboot-quotidien.sh install`

### Vérifications avant installation

L'installation est refusée si l'un de ces points échoue :

- erreurs I/O, resets de lien ou NCQ désactivé dans `dmesg` ;
- RAID dégradé (`/proc/mdstat`) ;
- `/home` monté mais absent de `/etc/fstab` ;
- RAID absent de `/etc/mdadm/mdadm.conf`.

### Fuseau horaire

L'heure du reboot suit le fuseau du serveur (souvent UTC). Vérifiez-le avec `timedatectl` : à 4h UTC, il est 6h à Paris en été et 5h en hiver. Pour changer le fuseau : `timedatectl set-timezone Europe/Paris`.

### Journal

Chaque reboot planifié est consigné dans `/var/log/reboot-quotidien.log`.

### Avertissement

- Un reboot quotidien **masque les problèmes sans les corriger** (fuite mémoire, saturation disque). Cherchez la cause avant de l'automatiser.


xtream-phpfpm

Pour le récupérer et le lancer sur un autre serveur, le plus sûr est de le télécharger, de le relire, puis de l’exécuter, plutôt que de le piper directement dans bash :

wget -O tune-xtream-phpfpm.sh https://raw.githubusercontent.com/wiijiitoolsecurite/PortGuard/main/tune-xtream-phpfpm.sh
chmod +x tune-xtream-phpfpm.sh
./tune-xtream-phpfpm.sh --dry-run
./tune-xtream-phpfpm.sh --restart
- Faites **un reboot manuel en journée creuse** avant la première nuit automatique, et vérifiez que `/home` remonte et que vos services repartent seuls.
- Ne l'utilisez pas sur une machine dont un disque est défaillant : un disque instable peut empêcher un RAID de se réassembler au redémarrage.
- Les services sont coupés pendant 1 à 3 minutes à chaque reboot.
- Testé sur Ubuntu 18.04 et 20.04. À utiliser à vos risques.
