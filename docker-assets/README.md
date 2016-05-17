# ManageIQ Docker Appliance

This image provides ManageIQ using the official Centos7 dockerhub build as a base along with PostgreSQL.

## Build

A typical build takes around 15 mins to complete.
It needs to be initiated from the root directory of the manageiq git repository

```
docker build -t manageiq .
```

The image has been tested and validated under docker-1.10 (Fedora23) and 1.8.2 (Centos7)


## Run

### On standard distribution

The first time you run the container, it will initialize the database, **please allow 2-4 mins** for MIQ to respond.
```
docker run --privileged -di -p 80:80 -p 443:443 manageiq
```
Please note you can ommit some ports from the run command if you don't need to use them


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
