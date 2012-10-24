#!/bin/bash

# postinstall.sh created from Mitchell's official lucid32/64 baseboxes

date > /etc/vagrant_box_build_time

export DEBIAN_FRONTEND=noninteractive
sed 's@us.archive.ubuntu.com@be.archive.ubuntu.com@' -i /etc/apt/sources.list

# Apt-install various things necessary for Ruby, guest additions,
# etc., and remove optional things to trim down the machine.
apt-get -y update
yes | apt-get -y install python-software-properties
echo 'deb http://repo.percona.com/apt precise main' > /etc/apt/sources.list.d/percona.list
apt-get -y update
yes | apt-get -y -o 'DPkg::Options::=--force-confold' dist-upgrade
apt-get -y install linux-headers-$(uname -r) build-essential
apt-get -y install zlib1g-dev libssl-dev libreadline-gplv2-dev
apt-get -y install vim
apt-get clean

# Installing the virtualbox guest additions
apt-get -y install dkms
VBOX_VERSION=$(cat /home/vagrant/.vbox_version)
cd /tmp
wget http://download.virtualbox.org/virtualbox/$VBOX_VERSION/VBoxGuestAdditions_$VBOX_VERSION.iso
mount -o loop VBoxGuestAdditions_$VBOX_VERSION.iso /mnt
sh /mnt/VBoxLinuxAdditions.run
umount /mnt

rm VBoxGuestAdditions_$VBOX_VERSION.iso

# Setup sudo to allow no-password sudo for "admin"
groupadd -r admin
usermod -a -G admin vagrant
cp /etc/sudoers /etc/sudoers.orig
sed -i -e '/Defaults\s\+env_reset/a Defaults\texempt_group=admin' /etc/sudoers
sed -i -e 's/%admin ALL=(ALL) ALL/%admin ALL=NOPASSWD:ALL/g' /etc/sudoers

# Install NFS client
apt-get -y install nfs-common

apt-get -y install ruby

# Installing chef & Puppet
apt-get -y install chef
apt-get -y install puppet

# Installing vagrant keys
mkdir /home/vagrant/.ssh
chmod 700 /home/vagrant/.ssh
cd /home/vagrant/.ssh
wget --no-check-certificate 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' -O authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant /home/vagrant/.ssh

# Remove items used for building, since they aren't needed anymore
apt-get -y remove linux-headers-$(uname -r) build-essential
apt-get -y autoremove

# Zero out the free space to save space in the final image:
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

# Removing leftover leases and persistent rules
echo "cleaning up dhcp leases"
rm /var/lib/dhcp3/*

# Make sure Udev doesn't block our network
# http://6.ptmc.org/?p=164
echo "cleaning up udev rules"
rm /etc/udev/rules.d/70-persistent-net.rules
mkdir /etc/udev/rules.d/70-persistent-net.rules
rm -rf /dev/.udev/
rm /lib/udev/rules.d/75-persistent-net-generator.rules


yes | apt-get -y install acl

echo "add some services and settings based on the scalingphp ebook"

yes | apt-get -y install nscd


cat <<EOF > /etc/sysctl.d/50-tuning.conf
net.core.somaxconn=100000
net.ipv4.ip_local_port_range="10000 61000"
net.ipv4.ipv4.tcp_tw_reuse=1
vm.swappiness=0
EOF
sysctl -p

ulimit -n 100000
cat <<EOF > /etc/security/limits.conf
# /etc/security/limits.conf
#
#Each line describes a limit for a user in the form:
#
#<domain>        <type>  <item>  <value>
#
#Where:
#<domain> can be:
#        - an user name
#        - a group name, with @group syntax
#        - the wildcard *, for default entry
#        - the wildcard %, can be also used with %group syntax,
#                 for maxlogin limit
#        - NOTE: group and wildcard limits are not applied to root.
#          To apply a limit to the root user, <domain> must be
#          the literal username root.
#
#<type> can have the two values:
#        - "soft" for enforcing the soft limits
#        - "hard" for enforcing hard limits
#
#<item> can be one of the following:
#        - core - limits the core file size (KB)
#        - data - max data size (KB)
#        - fsize - maximum filesize (KB)
#        - memlock - max locked-in-memory address space (KB)
#        - nofile - max number of open files
#        - rss - max resident set size (KB)
#        - stack - max stack size (KB)
#        - cpu - max CPU time (MIN)
#        - nproc - max number of processes
#        - as - address space limit (KB)
#        - maxlogins - max number of logins for this user
#        - maxsyslogins - max number of logins on the system
#        - priority - the priority to run user process with
#        - locks - max number of file locks the user can hold
#        - sigpending - max number of pending signals
#        - msgqueue - max memory used by POSIX message queues (bytes)
#        - nice - max nice priority allowed to raise to values: [-20, 19]
#        - rtprio - max realtime priority
#        - chroot - change root to directory (Debian-specific)
#
#<domain>      <type>  <item>         <value>
#

#*               soft    core            0
#root            hard    core            100000
#*               hard    rss             10000
#@student        hard    nproc           20
#@faculty        soft    nproc           20
#@faculty        hard    nproc           50
#ftp             hard    nproc           0
#ftp             -       chroot          /ftp
#@student        -       maxlogins       4

*                soft    nofile          100000
*                hard    nofile          100000

# End of file
EOF

yes | apt-get -y install apache2 apache2-mpm-worker apache2-threaded-dev libapache2-mod-rpaf libapache2-mod-fastcgi

a2enmod rewrite
a2enmod ssl

yes | apt-get -y install percona-server-server-5.5 percona-server-client-5.5 percona-toolkit

yes | apt-get -y install sysv-rc-conf php5-fpm php5-mysqlnd php5-imagick php5-mcrypt php5-cli php5-gd php5-memcached php5-curl php5-intl php5-dev php-pear build-essential libmagick++-dev
yes | pecl install APC-beta

cat <<EOF > /etc/php5/conf.d/50-apc.ini
extension=apc.so
apc.enabled = 1
apc.shm_segments = 1
apc.shm_size = 2G
apc.num_files_hint = 1000
apc.user_entries_hint = 4096
apc.ttl = 0
apc.user_ttl = 0
apc.gc_ttl = 3600
apc.cache_by_default = 1
apc.filters = "apc\.php$"
apc.mmap_file_mask = "/tmp/apc.XXXXXX"
apc.slam_defense = 0
apc.file_update_protection = 2
apc.enable_cli = 0
apc.max_file_size = 10M
apc.use_request_time = 1
apc.stat = 1
apc.write_lock = 1
apc.report_autofilter = 0
apc.include_once_override = 0
apc.localcache = 0
apc.localcache.size = 256M
apc.coredump_unmap = 0
apc.stat_ctime = 0
apc.canonicalize = 1
apc.lazy_functions = 0
apc.lazy_classes = 0
EOF

cat <<EOF > /etc/php5/conf.d/99-kunstmaan.ini
[kunstmaan]
max_execution_time = 7200
max_input_time = 7200
memory_limit = -1
post_max_size = 200M
upload_max_filesize = 200M
max_file_uploads = 100
date.timezone = Europe/Brussels
date.default_latitude = 50.877369
date.default_longitude = 4.684167
EOF


a2enmod actions
a2enmod fastcgi

cat <<EOF > /etc/apache2/mods-available/fastcgi.conf
<IfModule mod_fastcgi.c>
  AddHandler php5-fcgi .php
  Action php5-fcgi /php5-fpm/php5.external
  <Location "/php5-fpm/php5.external">
    Order Deny,Allow
    Deny from All
    Allow from env=REDIRECT_STATUS
  </Location>
</IfModule>

EOF
sysv-rc-conf --level 2345 php5-fpm on

yes | apt-get -y install git
yes | apt-get -y install varnish
locale-gen nl_BE
locale-gen fr_BE
locale-gen en_GB
locale-gen es_ES
locale-gen nl_BE.utf8
locale-gen fr_BE.utf8
locale-gen en_GB.utf8
locale-gen es_ES.utf8
git clone https://github.com/roderik/dotfiles.git /tmp/dotfiles
rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" --exclude "Sublime Text 2" --exclude "README.md" -a /tmp/dotfiles/* /root/
rsync --exclude ".git/" --exclude ".DS_Store" --exclude "bootstrap.sh" --exclude "Sublime Text 2" --exclude "README.md" -a /tmp/dotfiles/* /home/vagrant
rm -Rf /tmp/dotfiles
yes | apt-get -y install ntp optipng jpegoptim curl glances htop
gem install kstrano
curl -s https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod a+x /usr/local/bin/composer
yes | apt-get -y install postfix

apt-get -qq autoclean
apt-get -qq clean

echo "Adding a 2 sec delay to the interface up, to make the dhclient happy"
echo "pre-up sleep 2" >> /etc/network/interfaces
exit
