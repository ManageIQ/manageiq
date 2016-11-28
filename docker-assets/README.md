# ManageIQ Docker Appliance

This image provides ManageIQ using the official Centos7 dockerhub build as a base along with PostgreSQL.

## Build

A typical build takes around 15 mins to complete.
It needs to be initiated from the root directory of the manageiq git repository

```
docker build -t manageiq/manageiq .
```
please note:
- in the example above we named the image manageiq/manageiq, but in fact when building from your own sources you can name the image the way you want it to be (e.g. branch name), if you do that, don't forget to run it using the same name.
- you can do it from any branch you want and the build will also incluse all of you local changes in the appliance (including unmerged changes)
- when building from a local branch which is not based on master you'll need the specific REF (see below) to pull in the appropriate additional appliance repos.
- when building from a local branch based on master there is no need for any additional parameters and the above command is all you need. 

To build versions from a specific manageiq REF (either branch or tag):

```
docker build -t manageiq/manageiq:darga --build-arg REF=darga .                 # From tip of darga branch
docker build -t manageiq/manageiq:darga-1-beta1 --build-arg REF=darga-1-beta1 . # From darga-1-beta1 tag
```


The image has been tested and validated under docker-1.10.3 (Fedora24)


## Run

### On standard distribution

The first time you run the container, it will initialize the database, **please allow 2-4 mins** for MIQ to respond.

```
docker run --privileged -di -p 80:80 -p 443:443 manageiq/manageiq
```
Please note you can ommit some ports from the run command if you don't need to use them

_**Note:**_ If you are running a RHEL family docker host you can now run the MIQ container unprivileged as recent versions of docker (1.10.3). Please ensure oci-systemd-hook and oci-register-machine packages are installed in your system.
```
docker run -di -p 80:80 -p 443:443 manageiq/manageiq
```

### On Atomic host

```
atomic install -n <name> manageiq
atomic run -n <name> manageiq
atomic stop -n <name>  manageiq
atomic uninstall -n <name> manageiq
```

## Pull and use latest image from Docker Hub

### On standard distribution
```
docker run --privileged -di -p 80:80 -p 443:443 docker.io/manageiq/manageiq
```

### On Atomic host

```
atomic install docker.io/manageiq/manageiq
atomic run docker.io/manageiq/manageiq
```
Note due to resource limitations you can not run more than a single container of manageiq on the same Atomic host

## Access
The web interface is exposed at port 443. Default login credentials.

Point your web browser to :

```
https://<your-ip-address>
```

For console access, please use docker exec from docker host :
```
docker exec -ti <container-id> bash -l
```

## Logging
We can display systemd container journal logs on the docker host thanks to OCI systemd hooks on RHEL family systems

Ensure the MIQ container has been registered with machinectl on docker host :
```bash
machinectl
MACHINE                          CLASS     SERVICE
79c9df0368a8e83c7dc7ed915d0b7f7d container docker

1 machines listed.
```
Use machinectl to show status of container :
```bash
machinectl status 79c9df0368a8e83c7dc7ed915d0b7f7d
79c9df0368a8e83c7dc7ed915d0b7f7d(37396339646630333638613865383363)
           Since: Tue 2016-11-15 12:59:36 EST; 3h 2min ago
          Leader: 7978 (systemd)
         Service: docker; class container
            Root: /var/lib/docker/devicemapper/mnt/e3c30d2e34cca063633f12d461e56f6b88cb4e155d09cf9da7049739f7db3a51/rootfs
            Unit: docker-79c9df0368a8e83c7dc7ed915d0b7f7dbdfff15a9366b12272110e5331e5c54e.scope
                  ├─7978 /usr/sbin/init
                  └─system.slice
                    ├─dbus.service
                    │ └─8159 /bin/dbus-daemon --system --address=systemd: --nofork --nopidfile --systemd-activation
                    ├─evmserverd.service
                    │ ├─8446 MIQ Server                                                                     
                    │ ├─8665 MIQ: MiqGenericWorker id: 1, queue: generic                                    
                    │ ├─8673 MIQ: MiqGenericWorker id: 2, queue: generic                                    
                    │ ├─8683 MIQ: MiqPriorityWorker id: 3, queue: generic                                   
                    │ ├─8691 MIQ: MiqPriorityWorker id: 4, queue: generic                                   
                    │ ├─8701 MIQ: MiqScheduleWorker id: 5                                                   
                    │ ├─8722 MIQ: MiqEventHandler id: 6, queue: ems                                         
                    │ ├─8731 MIQ: MiqReportingWorker id: 7, queue: reporting                                
                    │ ├─8739 MIQ: MiqReportingWorker id: 8, queue: reporting                                
                    │ ├─8750 puma 3.3.0 (tcp://127.0.0.1:5000) [MIQ: Web Server Worker]                     
                    │ ├─8781 puma 3.3.0 (tcp://127.0.0.1:3000) [MIQ: Web Server Worker]                     
                    │ └─8795 puma 3.3.0 (tcp://127.0.0.1:4000) [MIQ: Web Server Worker]                     
                    ├─memcached.service
                    │ └─8639 /usr/bin/memcached -u memcached -p 11211 -m 64 -c 1024 -l 127.0.0.1 -I 1
...
```
Use journalctl to display container journal from docker host :
```bash
journalctl -M 79c9df0368a8e83c7dc7ed915d0b7f7d
-- Logs begin at Tue 2016-11-15 12:59:38 EST, end at Tue 2016-11-15 13:04:02 EST. --
Nov 15 12:59:38 79c9df0368a8 systemd-journal[20]: Runtime journal is using 4.0M (max allowed 8.0M, trying to leave 9.6M free of 59.9M available → current limit 8.0M).
Nov 15 12:59:38 79c9df0368a8 systemd-journal[20]: Permanent journal is using 8.0M (max allowed 1022.2M, trying to leave 1.4G free of 8.3G available → current limit 1022.2M).
Nov 15 12:59:38 79c9df0368a8 systemd-journal[20]: Time spent on flushing to /var is 1.491ms for 2 entries.
Nov 15 12:59:38 79c9df0368a8 systemd-journal[20]: Journal started
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Started Create Volatile Files and Directories.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Dependency failed for Update UTMP about System Runlevel Changes.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Job systemd-update-utmp-runlevel.service/start failed with result 'dependency'.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Reached target System Initialization.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Starting System Initialization.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Started Daily Cleanup of Temporary Directories.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Starting Daily Cleanup of Temporary Directories.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Reached target Timers.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Starting Timers.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Listening on D-Bus System Message Bus Socket.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Starting D-Bus System Message Bus Socket.
Nov 15 12:59:38 79c9df0368a8 systemd[1]: Reached target Sockets.
...
```
