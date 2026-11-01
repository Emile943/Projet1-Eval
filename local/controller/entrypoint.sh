#!/bin/sh
# Copie la clé privée montée vers ~/.ssh avec les droits 600.
# Pourquoi : sous Windows, un fichier monté est lisible par tous et le client SSH
# refuse alors de l'utiliser ("UNPROTECTED PRIVATE KEY FILE").
mkdir -p /root/.ssh && chmod 700 /root/.ssh
cp /run/secrets/id_ed25519 /root/.ssh/id_ed25519
chmod 600 /root/.ssh/id_ed25519
exec "$@"