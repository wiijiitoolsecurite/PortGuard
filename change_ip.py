#!/usr/bin/env python
# -*- coding: utf-8 -*-
import sys, os, json, glob, shutil, base64, re
from itertools import cycle

KEY = '5709650b0d7806074842c6de575025b1'
DEFAULT_GLOB = '/home/*/iptv_xtream_codes/config'

def xor(data, key):
    kb = bytearray(key.encode('utf-8'))
    return bytes(bytearray(b ^ k for b, k in zip(bytearray(data), cycle(kb))))

def decrypt(path):
    raw = open(path, 'rb').read().strip()
    return json.loads(xor(base64.b64decode(raw), KEY).decode('utf-8'))

def encrypt(path, c):
    s = '{"host":"%s","db_user":"%s","db_pass":"%s","db_name":"%s","server_id":"%d", "db_port":"%d"}' % (
        c["host"], c["db_user"], c["db_pass"], c["db_name"], int(c["server_id"]), int(c["db_port"]))
    with open(path, 'wb') as f:
        f.write(base64.b64encode(xor(s.encode('utf-8'), KEY)))

def main():
    if len(sys.argv) < 2 or not re.match(r'^\d{1,3}(\.\d{1,3}){3}$', sys.argv[1]):
        print("Usage: %s NOUVELLE_IP [fichier_config ...]" % sys.argv[0])
        sys.exit(1)

    new_ip = sys.argv[1]
    paths = sys.argv[2:] or glob.glob(DEFAULT_GLOB)
    if not paths:
        print("Aucun fichier config trouve.")
        sys.exit(1)

    for p in paths:
        try:
            c = decrypt(p)
            old_ip = c["host"]
            shutil.copy2(p, p + ".bak")
            c["host"] = new_ip
            encrypt(p, c)
            print("[OK] %s : %s -> %s (sauvegarde: %s.bak)" % (p, old_ip, new_ip, p))
        except Exception as e:
            print("[ERREUR] %s : %s" % (p, e))

if __name__ == "__main__":
    main()
