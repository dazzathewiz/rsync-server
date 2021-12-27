## rsync-server

A `rsyncd`/`sshd` server in Docker. You know, for moving files.


### quickstart

Start a server (both `sshd` and `rsyncd` are supported)
- SSH server with default root:pass (username/password)
- RSYNCD server with "volume" module name linked to /data volume passed through; user:pass (username/password)

```
$ docker run \ 
    --name rsync-server \
    -p 12000:873 \
    -p 22:22  \
    -v /your/rsync/volume:/data \
    dazzathewiz/rsync-server
```

docker-compose
```
rsync-server:
    container_name: rsync-server
    restart: always
    environment: 
        # (optional) - use only if non-default values should be used
        RSYNC_TIMEOUT: 300
        RSYNC_PORT: 873
        RSYNC_MAX_CONNECTIONS: 10

        # (optional) - global username and password. SSH and RSYNC will use the same PASSWORD
        PASSWORD: foobar
        USERNAME: rsync
        
        # (optional) ID_NAME is the only required parameter for each rsync module
        MOD1_NAME: Backup_From
        MOD1_VOLUME: /vol2
        MOD2_USERNAME: test
        MOD2_PASSWORD: secret
        MOD2_UID: nobody
        MOD2_GID: nobody
        MOD1_ALLOW: 192.168.1.0/24
        MOD1_READ_ONLY: "true"
        MOD2_EXCLUDE: /backup

        MOD2_NAME: Backup_To
        MOD2_VOLUME: /vol
        MOD2_ALLOW: 192.168.1.0/24
        MOD2_READ_ONLY: "false"

        # (optional) SSH configuration
        SSH_PORT = 22
        SSH_ENABLE_PASSWORD_LOGIN = true        #turns off password authentication on SSH
        SSH_KEY = 'ssh-rsa xxxx root@machine'   #enter you public SSH authorized_keys for passwordless auth

    volumes:
        - /data:/vol2
        - /data/backup:/vol
    ports:
        - "873:873"
        - "22:22"
    image: dazzathewiz/rsync-server
```

### `rsyncd`

- Looking at the example compose file, the first three environment variables are completely optional and are predefined in the image.

- `USERNAME` and `PASSWORD` can be used to define a simple authentication which is used for all Rsync modules. If these parameters are not specified, authentication is disabled by default. This can be overwritten by module-wise environment variables

To define a Rsync module a simple `ID_NAME` is needed as environment variable. ID can be any letter or number and is of your choosing. The ID is used to identify all corresponding parameters. All other parameters are optional.

- `ID_NAME`: unique name of the Rsync module
- `ID_VOLUME`: path of the Rsync module, this should be a volume mounted to the container (/vol is the default directory if no VOLUME parameter is specified)
- `ID_USERNAME` and `ID_PASSWORD`: these two parameters can overwrite the global authentication parameters. If no global authentication is specified, it enables the username and password only for this specific Rsync module
- `ID_UID` and `ID_GID`: by default the rsyncd runs with root privileges, this can be overwritten for a specific module when uid and/or gid are declared
- `ID_ALLOW`: allows only specified IP addresses/ranges to connect to the Rsync module. If not declared all network addresses can connect to it
- `ID_READ_ONLY`: states if module is read only or not. It defaults to true.
- `ID_EXCLUDE`: this parameter can be used to exclude file patterns or folders from the rsync module

```
$ rsync -av /your/folder/ rsync://user@localhost:8000/volume
Password: pass
sending incremental file list
./
foo/
foo/bar/
foo/bar/hi.txt

sent 166 bytes  received 39 bytes  136.67 bytes/sec
total size is 0  speedup is 0.00
```


#### `sshd`

Please note that you are connecting as the `root` and not the user specified in
the `USERNAME` variable. If you don't supply a key file you will be prompted
for the `PASSWORD`. **It is recommended that you always change the default password of `pass` by setting the `PASSWORD` environmental variable, even if you are using key authentication.**

If `SSH_ENABLE_PASSWORD_LOGIN` is set to anything other than 'true', SSHD disables password auth for root and must use an `SSH_KEY` for key based auth to work.



### Usage

Variable options (on run)

* `USERNAME` - the `rsync` username. defaults to `user`
* `PASSWORD` - the `rsync` password. defaults to `pass`
* `VOLUME`   - the path for `rsync`. defaults to `/data`
* `ALLOW`    - space separated list of allowed sources.


##### Simple server on port 873

```
$ docker run -p 873:873 dazzathewiz/rsync-server
```


##### Use a volume for the default `/data`

```
$ docker run -p 873:873 -v /your/folder:/data dazzathewiz/rsync-server
```

##### Set a username and password

```
$ docker run \
    -p 873:873 \
    -v /your/folder:/data \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    dazzathewiz/rsync-server
```

##### Run on a custom port

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/data \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    dazzathewiz/rsync-server
```

```
$ rsync rsync://admin@localhost:9999
volume            /data directory
```


##### Modify the default volume location

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    dazzathewiz/rsync-server
```

```
$ rsync rsync://admin@localhost:9999
volume            /myvolume directory
```

##### Allow additional client IPs

```
$ docker run \
    -p 9999:873 \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    -e ALLOW=192.168.8.0/24 192.168.24.0/24 172.16.0.0/12 127.0.0.1/32 \
    dazzathewiz/rsync-server
```


##### Over SSH

If you would like to connect over ssh, you may mount your public key or
`authorized_keys` file to `/root/.ssh/authorized_keys`.

Without setting up an `authorized_keys` file, you will be propted for the
password (which was specified in the `PASSWORD` variable).

Please note that when using `sshd` **you will be specifying the actual folder
destination as you would when using SSH.** On the contrary, when using the
`rsyncd` daemon, you will always be using `/volume`, which maps to `VOLUME`
inside of the container, or another module as defined.

```
docker run \
    -v /your/folder:/myvolume \
    -e USERNAME=admin \
    -e PASSWORD=mysecret \
    -e VOLUME=/myvolume \
    -e ALLOW=192.168.8.0/24 192.168.24.0/24 172.16.0.0/12 127.0.0.1/32 \
    -v /my/authorized_keys:/root/.ssh/authorized_keys \
    -p 9000:22 \
    dazzathewiz/rsync-server
```

```
$ rsync -av -e "ssh -i /your/private.key -p 9000 -l root" /your/folder/ localhost:/data
```
