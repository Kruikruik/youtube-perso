#!/usr/bin/env bash
# Les patchs ReVanced ne sont plus publiés sur GitHub (dépôt retiré en 2026).
# Le fichier .rvp est distribué par l'API officielle de ReVanced.
# Le builder ne sait télécharger que depuis GitHub : on pré-télécharge donc le .rvp
# dans son cache (temp/revanced-rv/), qu'il réutilise ensuite tel quel.
set -euo pipefail

CFG=${1:-config.toml}
API="https://api.revanced.app/v5/patches"

VER=$(python3 -I - "$CFG" <<'PY'
import sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb"))
glob_src = cfg.get("patches-source", "MorpheApp/morphe-patches")
glob_ver = cfg.get("patches-version", "latest")
vers = set()
for k, v in cfg.items():
    if isinstance(v, dict) and v.get("enabled", True):
        if v.get("patches-source", glob_src).lower() == "revanced/revanced-patches":
            vers.add(v.get("patches-version", glob_ver))
print(" ".join(sorted(vers)))
PY
)
if [ -z "$VER" ]; then echo "Aucune app ReVanced dans la config, rien à faire."; exit 0; fi

info=$(curl -fsSL "$API")
api_ver=$(jq -r .version <<<"$info")
url=$(jq -r '.download_url // "https://api.revanced.app/v5/patches.rvp"' <<<"$info")
echo "Patchs ReVanced disponibles : $api_ver ($url)"

for v in $VER; do
  if [ "$v" != "latest" ] && [ "${v#v}" != "${api_ver#v}" ]; then
    echo "La config demande $v mais l'API ReVanced ne sert que $api_ver."
    echo "Mets patches-version = \"$api_ver\" (ou \"latest\") pour Twitch dans config.toml."
    exit 1
  fi
done

mkdir -p temp/revanced-rv
out="temp/revanced-rv/patches-${api_ver#v}.rvp"
curl -fsSL -o "$out" "$url"
unzip -l "$out" >/dev/null || { echo "Le fichier téléchargé n'est pas un .rvp valide"; exit 1; }
echo "REVANCED_PATCHES_TAG=${api_ver}" >> "${GITHUB_ENV:-/dev/null}"
ls -l temp/revanced-rv
