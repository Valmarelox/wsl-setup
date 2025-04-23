#!/bin/sh

if [ "$UID" -ne 0 ]; then
    echo "This script must be run as root."
    exit 1
fi

FULL_NAME="$1"
EMAIL="$2"
shift 2
if [ -z "$FULL_NAME" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <full_name> <email>"
    exit 1
fi

set -ex
# Basics

apt update --yes
apt dist-upgrade --yes
apt install --yes etckeeper
apt install --yes git fzf fd-find ripgrep vim zip jq

apt install --yes python3-pip python3-virtualenv
apt install --yes curl
# make plocate not index 9p (wsl windows mounts)
echo << EOF
PRUNE_BIND_MOUNTS="yes"
# PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /media /var/lib/os-prober /var/lib/ceph /home/.ecryptfs /var/lib/schroot"
PRUNEFS="NFS afs autofs binfmt_misc ceph cgroup cgroup2 cifs coda configfs curlftpfs debugfs devfs devpts devtmpfs ecryptfs ftpfs fuse.ceph fuse.cryfs fuse.encfs fuse.glusterfs fuse.gocryptfs fuse.gvfsd-fuse fuse.mfs fuse.rclone fuse.rozofs fuse.sshfs fusectl fusesmb hugetlbfs iso9660 lustre lustre_lite mfs mqueue ncpfs nfs nfs4 ocfs ocfs2 proc pstore rpc_pipefs securityfs shfs smbfs sysfs tmpfs tracefs udev udf usbfs 9p"
EOF
apt install --yes plocate

echo '. /usr/share/doc/fzf/examples/key-bindings.bash' >> /etc/bash.bashrc


# Zoomer stuff

curl -L https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt update --yes && apt install --yes terraform
terraform -install-autocomplete


STABLE_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${STABLE_VER}/bin/linux/amd64/kubectl"
echo "$(curl -L "https://dl.k8s.io/release/${STABLE_VER}/bin/linux/amd64/kubectl.sha256") kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
# kubectl completion
echo "source <(kubectl completion bash)" >> /etc/bash.bashrc
# kubectl aliases
echo "alias k=kubectl" >> /etc/bash.bashrc
echo "complete -F __start_kubectl k" >> /etc/bash.bashrc
# kubectx
sudo apt install --yes kubectx

# Snap :(
sudo snap install aws-cli --classic

# Git and gpg config
gpg --batch --generate-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: $FULL_NAME
Name-Email: $EMAIL
Expire-Date: 0
%commit
EOF

GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{print $2}' | cut -d'/' -f2)

git config --global user.email $EMAIL
git config --global user.name "$FULL_NAME"
git config --global user.signingkey "$GPG_KEY_ID"
git config --global commit.gpgsign true
git config --global core.editor "vim"
# TODO: Hack
ssh-keygen -t ecdsa -b 521 -f /home/$(id -un 1000)/.ssh/id_ed25519 -N "" -C "$UID@$(hostname)"


echo "[*] Post Install steps:"
echo "1. Add your gpg key to github: gpg --armor --export $GPG_KEY_ID"
echo "2. Add your ssh key to github: cat /home/$(id -un 1000)/.ssh/id_ed25519.pub"


set +ex