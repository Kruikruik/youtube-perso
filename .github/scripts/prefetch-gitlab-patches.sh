#!/usr/bin/env bash
# Les patchs ReVanced ne sont plus publiés sur GitHub (dépôt retiré en 2026),
# seulement sur GitLab. Le builder ne sait télécharger que depuis GitHub :
# on pré-télécharge donc le .rvp dans le cache du builder (temp/revanced-rv/),
# qu'il réutilise ensuite sans rien demander à GitHub.
set -euo pipefail

CFG=${1:-config.toml}
PROJECT="ReVanced%2Frevanced-patches"
API="https://gitlab.com/api/v4/projects/${PROJECT}/releases"

# Version demandée dans config.toml pour les apps qui utilisent ReVanced/revanced-patches
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

mkdir -p temp/revanced-rv
for v in $VER; do
  if [ "$v" = "latest" ]; then
    rel=$(curl -fsSL "${API}/permalink/latest")
  else
    rel=$(curl -fsSL "${API}/${v}")
  fi
  tag=$(jq -r .tag_name <<<"$rel")
  url=$(jq -r '[.assets.links[] | select(.name | endswith(".rvp"))][0].direct_asset_url // [.assets.links[] | select(.name | endswith(".rvp"))][0].url' <<<"$rel")
  if [ -z "$url" ] || [ "$url" = "null" ]; then echo "Pas de .rvp trouvé pour $tag"; exit 1; fi
  out="temp/revanced-rv/patches-${tag#v}.rvp"
  echo "Téléchargement des patchs ReVanced $tag -> $out"
  curl -fsSL -o "$out" "$url"
  echo "REVANCED_PATCHES_TAG=$tag" >> "${GITHUB_ENV:-/dev/null}"
done
ls -l temp/revanced-rv
