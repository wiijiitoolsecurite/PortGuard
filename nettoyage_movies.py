#!/usr/bin/env python3

import os
import re
import sys

MOVIES_DIR = "/home/xtreamcodes/iptv_xtream_codes/movies"
MAX_ID_BACKUP = 462885

# Extensions vidéo autorisées
VIDEO_EXTENSIONS = {
    ".mkv", ".mp4", ".avi", ".ts", ".mov", ".m4v"
}


def format_size(size):
    units = ["B", "KB", "MB", "GB", "TB"]
    size = float(size)

    for unit in units:
        if size < 1024:
            return f"{size:.2f} {unit}"
        size /= 1024

    return f"{size:.2f} PB"


def scan_files():
    candidates = []
    total_size = 0

    print(f"Scan de : {MOVIES_DIR}")
    print(f"ID maximum conservé : {MAX_ID_BACKUP}")
    print("-" * 60)

    try:
        entries = os.scandir(MOVIES_DIR)
    except Exception as e:
        print(f"ERREUR : impossible d'ouvrir {MOVIES_DIR}")
        print(e)
        sys.exit(1)

    with entries:
        for entry in entries:

            if not entry.is_file(follow_symlinks=False):
                continue

            name = entry.name
            base, extension = os.path.splitext(name)

            # Sécurité : uniquement ID numérique + extension vidéo connue
            if not re.fullmatch(r"\d+", base):
                continue

            if extension.lower() not in VIDEO_EXTENSIONS:
                continue

            stream_id = int(base)

            if stream_id <= MAX_ID_BACKUP:
                continue

            try:
                size = entry.stat(follow_symlinks=False).st_size
            except OSError:
                continue

            candidates.append((stream_id, entry.path, size))
            total_size += size

    candidates.sort(key=lambda x: x[0])

    return candidates, total_size


def main():

    candidates, total_size = scan_files()

    print()
    print("=" * 60)
    print("RÉSULTAT")
    print("=" * 60)

    print(f"Fichiers à supprimer : {len(candidates)}")
    print(f"Espace à libérer     : {format_size(total_size)}")

    if not candidates:
        print("\nAucun fichier à supprimer.")
        return

    print("\nPremiers fichiers :")

    for stream_id, path, size in candidates[:10]:
        print(f"  {stream_id} -> {os.path.basename(path)} ({format_size(size)})")

    print("\nDerniers fichiers :")

    for stream_id, path, size in candidates[-10:]:
        print(f"  {stream_id} -> {os.path.basename(path)} ({format_size(size)})")

    print()
    print("ATTENTION")
    print(f"Tous les fichiers vidéo avec ID > {MAX_ID_BACKUP}")
    print("seront SUPPRIMÉS DÉFINITIVEMENT.")
    print()
    print(f"Nombre : {len(candidates)}")
    print(f"Espace : {format_size(total_size)}")
    print()

    confirmation = input(
        'Tape exactement SUPPRIMER pour continuer : '
    )

    if confirmation != "SUPPRIMER":
        print("\nAnnulé. Aucun fichier supprimé.")
        return

    print("\nSuppression en cours...\n")

    deleted = 0
    deleted_size = 0
    errors = 0

    for stream_id, path, size in candidates:

        try:
            os.remove(path)

            deleted += 1
            deleted_size += size

            print(
                f"[{deleted}/{len(candidates)}] "
                f"Supprimé : {os.path.basename(path)}"
            )

        except Exception as e:
            errors += 1
            print(f"ERREUR : {path}")
            print(f"         {e}")

    print()
    print("=" * 60)
    print("TERMINÉ")
    print("=" * 60)

    print(f"Fichiers supprimés : {deleted}")
    print(f"Espace libéré       : {format_size(deleted_size)}")
    print(f"Erreurs             : {errors}")


if __name__ == "__main__":
    main()
