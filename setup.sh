#!/bin/sh

if [ "$UID" -eq 0 ]; then
    echo "This script must not be run as root."
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

sudo apt update --yes
sudo apt dist-upgrade --yes
sudo apt install --yes etckeeper
sudo apt install --yes git fzf fd-find ripgrep vim zip jq htop
echo '. /usr/share/doc/fzf/examples/key-bindings.bash' | sudo tee --append /etc/bash.bashrc

sudo apt install --yes python3-pip python3-virtualenv python3-ipython
sudo apt install --yes curl
sudo apt install --yes xdg-utils

# make plocate not index 9p (wsl windows mounts)
echo << EOF
PRUNE_BIND_MOUNTS="yes"
# PRUNENAMES=".git .bzr .hg .svn"
PRUNEPATHS="/tmp /var/spool /media /var/lib/os-prober /var/lib/ceph /home/.ecryptfs /var/lib/schroot"
PRUNEFS="NFS afs autofs binfmt_misc ceph cgroup cgroup2 cifs coda configfs curlftpfs debugfs devfs devpts devtmpfs ecryptfs ftpfs fuse.ceph fuse.cryfs fuse.encfs fuse.glusterfs fuse.gocryptfs fuse.gvfsd-fuse fuse.mfs fuse.rclone fuse.rozofs fuse.sshfs fusectl fusesmb hugetlbfs iso9660 lustre lustre_lite mfs mqueue ncpfs nfs nfs4 ocfs ocfs2 proc pstore rpc_pipefs securityfs shfs smbfs sysfs tmpfs tracefs udev udf usbfs 9p"
EOF
apt install --yes plocate



# Zoomer stuff
sudo apt install docker.io

curl -L https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list
apt update --yes && apt install --yes terraform
terraform -install-autocomplete
cat > ~/.terraformrc << EOF
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache/"
disable_checkpoint = true
EOF


STABLE_VER=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${STABLE_VER}/bin/linux/amd64/kubectl"
echo "$(curl -L "https://dl.k8s.io/release/${STABLE_VER}/bin/linux/amd64/kubectl.sha256") kubectl" | sha256sum --check
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl

# kubectl completion
echo "source <(kubectl completion bash)" >> ~/.bash_aliases
# kubectl aliases
echo "alias k=kubectl" >> ~/.bash_aliases
echo "complete -F __start_kubectl k" >> ~/.bashrc
# kubectx
sudo apt install --yes kubectx

sudo snap install --classic helm
helm completion bash | sudo tee /etc/bash_completion.d/helm > /dev/null

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
ssh-keygen -t ecdsa -b 521 -f ~/.ssh/id_ed25519 -N "" -C "$USER@$(hostname)"


# Useful as I mostly deal with code generated imagery & windows

echo << EOF | sudo tee /usr/share/applications/vscode.desktop
[Desktop Entry]
Name=Visual Studio Code - URL Handler
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=code %U
Icon=vscode
Type=Application
NoDisplay=true
StartupNotify=true
Categories=Utility;TextEditor;Development;IDE;
MimeType=x-scheme-handler/vscode;
Keywords=vscode;
EOF

sudo xdg-mime default vscode.desktop video/mp4
sudo xdg-mime default vscode.desktop video/png

echo "[*] Post Install steps:"
echo "1. Add your gpg key to github: gpg --armor --export $GPG_KEY_ID"
echo "2. Add your ssh key to github: cat /home/$(id -un 1000)/.ssh/id_ed25519.pub"



set +ex
