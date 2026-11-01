#un conteneur qui se comporte comme une VM Debian 12.
FROM debian:12

ENV DEBIAN_FRONTEND=noninteractive

# systemd = gestionnaire de services (PID 1), openssh-server = accès SSH
# python3 = requis par Ansible, sudo = élévation de droits.
RUN apt-get update && apt-get install -y --no-install-recommends \
    systemd systemd-sysv openssh-server python3 sudo \
    && rm -rf /var/lib/apt/lists/*

# Utilisateur "ansible", avec sudo sans mot de passe.
RUN useradd --create-home --shell /bin/bash ansible \
    && echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible \
    && chmod 0440 /etc/sudoers.d/ansible

# La clé publique sera montée dans /etc/ssh/authorized_keys/ansible
# StrictModes no : les fichiers montés depuis Windows ont des droits trop larges
# et sshd refuserait la clé.
RUN mkdir -p /etc/ssh/authorized_keys /run/sshd \
    && printf '%s\n' \
       'AuthorizedKeysFile /etc/ssh/authorized_keys/%u' \
       'PasswordAuthentication no' \
       'StrictModes no' \
       > /etc/ssh/sshd_config.d/lab.conf \
    && systemctl enable ssh

STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]