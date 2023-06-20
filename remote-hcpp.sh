#!/bin/bash

#
# Remote script to install and configure our HCPP (Hestia Control Panel Plugins).
# This script is run on the remote server with sudo permissions from the /tmp directory; it
# is invoked by the install-hcpp.sh script.
#

echo ""
echo "Starting automated HCPP installation"
echo "This will take a long while, please be patient..."
sleep 1

# Install HestiaCP Pluginable project
cd /tmp
git clone --depth 1 --branch "v1.0.0-beta.7" https://github.com/virtuosoft-dev/hestiacp-pluginable.git 2>/dev/null
mv hestiacp-pluginable/hooks /etc/hestiacp
rm -rf hestiacp-pluginable-main
/etc/hestiacp/hooks/post_install.sh
service hestia restart

# Install HCPP NodeApp
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0-beta.4" https://github.com/virtuosoft-dev/hcpp-nodeapp.git nodeapp 2>/dev/null
cd /usr/local/hestia/plugins/nodeapp
./install
touch "/usr/local/hestia/data/hcpp/installed/nodeapp"

# Install HCPP NodeRED
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0" https://github.com/virtuosoft-dev/hcpp-nodered.git nodered 2>/dev/null
cd /usr/local/hestia/plugins/nodered
./install
touch "/usr/local/hestia/data/hcpp/installed/nodered"

# Install HCPP MailCatcher
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0-beta.1" https://github.com/virtuosoft-dev/hcpp-mailcatcher.git mailcatcher 2>/dev/null
cd /usr/local/hestia/plugins/mailcatcher
./install
php -r 'require_once("/usr/local/hestia/web/pluginable.php");global $hcpp;$hcpp->do_action("hcpp_plugin_installed", "mailcatcher");'
touch "/usr/local/hestia/data/hcpp/installed/mailcatcher"

# Install HCPP VSCode
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0-beta.2" https://github.com/virtuosoft-dev/hcpp-vscode.git vscode 2>/dev/null
cd /usr/local/hestia/plugins/vscode
./install
touch "/usr/local/hestia/data/hcpp/installed/vscode"

# Install HCPP NodeBB
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0-beta.1" https://github.com/virtuosoft-dev/hcpp-nodebb.git nodebb 2>/dev/null
cd /usr/local/hestia/plugins/nodebb
./install
touch "/usr/local/hestia/data/hcpp/installed/nodebb"

# Install HCPP Ghost
cd /usr/local/hestia/plugins
git clone --depth 1 --branch "v1.0.0-beta.1" https://github.com/virtuosoft-dev/hcpp-ghost.git ghost 2>/dev/null
cd /usr/local/hestia/plugins/ghost
./install
touch "/usr/local/hestia/data/hcpp/installed/ghost"

# # Install HCPP WebDAV
# cd /usr/local/hestia/plugins
# git clone --depth 1 --branch "v0.0.1" https://github.com/virtuosoft-dev/hcpp-webdav.git webdav 2>/dev/null
# cd /usr/local/hestia/plugins/webdav
# ./install
# touch "/usr/local/hestia/data/hcpp/installed/webdav"

# Create our pws user and package
cd /usr/local/hestia/bin
cat <<EOT >> /tmp/pws.txt
PACKAGE='pws'
WEB_TEMPLATE='default'
BACKEND_TEMPLATE='default'
PROXY_TEMPLATE='default'
DNS_TEMPLATE='default'
WEB_DOMAINS='unlimited'
WEB_ALIASES='unlimited'
DNS_DOMAINS='unlimited'
DNS_RECORDS='unlimited'
MAIL_DOMAINS='unlimited'
MAIL_ACCOUNTS='unlimited'
RATE_LIMIT='200'
DATABASES='unlimited'
CRON_JOBS='unlimited'
DISK_QUOTA='unlimited'
BANDWIDTH='unlimited'
NS='ns1.dev.cc,ns2.dev.cc'
SHELL='bash'
BACKUPS='0'
EOT
./v-add-user-package /tmp/pws.txt pws
./v-add-user pws personal-web-server pws@dev.cc pws "Personal Web Server"
./v-update-user-package pws
chsh -s /bin/bash pws

# # Add Samba firewall rule
# ./v-add-firewall-rule ACCEPT 0.0.0.0/0 445 TCP SMB
# ./v-update-firewall

# # Add NFS exports
# cat <<EOT >> /etc/exports

# # Personal Web Server web folder
# /home/pws/web *(rw,sync,no_subtree_check)

# EOT

# # Add NFS firewall rule
# ./v-add-firewall-rule ACCEPT 0.0.0.0/0 2049 TCP SMB
# ./v-update-firewall

# Add the virtio pws appFolder mount point
mkdir -p /media/appFolder
cat <<EOT >> /etc/fstab

# Personal Web Server appFolder
appFolder /media/appFolder 9p _netdev,trans=virtio,version=9p2000.L,msize=104857600 0 0

EOT

# Add our public key copy script at bootup
cat <<EOT >> /usr/local/bin/copy_ssh_keys.sh
#!/bin/bash

# Wait for the mount point to be available
while [ ! -d "/media/appFolder" ]; do
    sleep 1
done

# Copy the SSH host keys to the mount point
cp /etc/ssh/ssh_host_ecdsa_key.pub /media/appFolder/ssh_host_ecdsa_key.pub
cp /etc/ssh/ssh_host_rsa_key.pub /media/appFolder/ssh_host_rsa_key.pub

EOT
chmod +x /usr/local/bin/copy_ssh_keys.sh
cat <<EOT >> /etc/systemd/system/copy_ssh_keys.service
[Unit]
Description=Copy SSH host keys to /media/appFolder
After=network.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 10
ExecStart=/usr/local/bin/copy_ssh_keys.sh

[Install]
WantedBy=multi-user.target

EOT
systemctl enable copy_ssh_keys.service

# Shutdown the server
echo "Shutting down the server."
shutdown now
