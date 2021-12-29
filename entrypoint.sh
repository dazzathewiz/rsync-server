#!/bin/bash
set -e

USERNAME=${USERNAME:-user}
PASSWORD=${PASSWORD:-pass}
VOLUME=${VOLUME:-/data}

setup_sshd(){
	if [ -e "/root/.ssh/authorized_keys" ]; then
        chmod 400 /root/.ssh/authorized_keys
        chown root:root /root/.ssh/authorized_keys
    else
		mkdir -p /root/.ssh
		chown root:root /root/.ssh
		echo "$SSH_KEY" > /root/.ssh/authorized_keys
		chmod 400 /root/.ssh/authorized_keys
        chown root:root /root/.ssh/authorized_keys
    fi
    chmod 750 /root/.ssh
	if [ $SSH_ENABLE_PASSWORD_LOGIN = "true" ]; then
    	echo "root:$PASSWORD" | chpasswd
		echo "[sshd_config] PermitRootLogin yes"
		sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
	else
		echo "[sshd_config] PermitRootLogin prohibit-password"
		sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
	fi
	echo "[sshd_config] SSH port set to: $SSH_PORT"
	sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
}

setup_rsyncd(){
	touch /etc/rsyncd.secrets
	chmod 0400 /etc/rsyncd.secrets

	cat << __EOF__ > /etc/rsyncd.conf
# GLOBAL OPTIONS
uid = root
gid = root
use chroot = true
pid file = /var/run/rsyncd.pid
log file = /dev/stdout
timeout = $RSYNC_TIMEOUT
max connections = $RSYNC_MAX_CONNECTIONS
port = $RSYNC_PORT
__EOF__

	for name in $(env | grep ".*_NAME.*"); do
		prefix=$(echo "$name" | cut -d '_' -f 1)

		name_var=$prefix"_NAME"
		uid_var=$prefix"_UID"
		gid_var=$prefix"_GID"
		allow_var=$prefix"_ALLOW"
		readonly_var=$prefix"_READ_ONLY"
		vol_var=$prefix"_VOLUME"
		user_var=$prefix"_USERNAME"
		pw_var=$prefix"_PASSWORD"
		exclude_var=$prefix"_EXCLUDE"

		rs_name=${!name_var}
		rs_uid=${!uid_var}
		rs_gid=${!gid_var}
		rs_allow=${!allow_var}
		rs_readonly=${!readonly_var}
		rs_vol=${!vol_var}
		rs_user=${!user_var}
		rs_pw=${!pw_var}
		rs_exclude=${!exclude_var}

		: ${rs_uid:=root}
		: ${rs_gid:=root}
		: ${rs_readonly:=true}
		: ${rs_vol:=$VOLUME}
		#: ${rs_user:=$USERNAME}
		#: ${rs_pw:=$PASSWORD}

		echo "[rsyncd_config]" $rs_name $rs_uid $rs_gid $rs_allow $rs_readonly $rs_vol $rs_user $rs_pw $rs_exclude
		cat << __EOF__ >> /etc/rsyncd.conf
# MODULE OPTIONS
[$rs_name]
    uid = $rs_uid
    gid = $rs_gid
    read only = $rs_readonly
    path = $rs_vol
    comment = $rs_name
    lock file = /var/lock/rsyncd
    list = yes
    ignore errors = no
    ignore nonreadable = yes
    transfer logging = yes
    log format = %t: host %h (%a) %o %f (%l bytes). Total %b bytes.
    refuse options = checksum dry-run
    dont compress = *.gz *.tgz *.zip *.z *.rpm *.deb *.iso *.bz2 *.tbz
    exclude = $rs_exclude *.!sync *.swp 
__EOF__

		if [ ! $rs_user = "" ]; then
			echo "    secrets file = /etc/rsyncd.secrets" >> /etc/rsyncd.conf
			echo "    auth users = $rs_user" >> /etc/rsyncd.conf
			echo "$rs_user:$rs_pw" >> /etc/rsyncd.secrets
		fi
		if [ ! $rs_allow = "" ]; then
			echo "    hosts deny = *" >> /etc/rsyncd.conf
			echo "    hosts allow = $rs_allow" >> /etc/rsyncd.conf
		fi
	done
	
	
	
	echo "$USERNAME:$PASSWORD" > /etc/rsyncd.secrets
    chmod 0400 /etc/rsyncd.secrets
	[ -f /etc/rsyncd.conf ] || cat > /etc/rsyncd.conf <<EOF
pid file = /var/run/rsyncd.pid
log file = /dev/stdout
timeout = 300
max connections = 10
port = 873

[volume]
	uid = root
	gid = root
	hosts deny = *
	hosts allow = ${ALLOW}
	read only = false
	path = ${VOLUME}
	comment = ${VOLUME} directory
	auth users = ${USERNAME}
	secrets file = /etc/rsyncd.secrets
EOF
}


if [ "$1" = 'rsync_server' ]; then
    setup_sshd
    exec /usr/sbin/sshd &
    mkdir -p $VOLUME
    setup_rsyncd
    exec /usr/bin/rsync --no-detach --daemon --config /etc/rsyncd.conf "$@"
else
	setup_sshd
	exec /usr/sbin/sshd &
fi

exec "$@"
