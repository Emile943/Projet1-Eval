#poste de contrôle avec Ansible.
FROM python:3.12-slim-bookworm

ENV ANSIBLE_HOST_KEY_CHECKING=False

# Client SSH pour se connecter aux nœuds.
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Ansible, son linter, et ce qu'il faut pour l'inventaire dynamique GCP.
RUN pip install --no-cache-dir ansible ansible-lint google-auth requests \
    && ansible-galaxy collection install google.cloud

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /workspace/ansible
ENTRYPOINT ["sh", "/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
#sleep infinity garde le conteneur allumé pour les commandes