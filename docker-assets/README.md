# ManageIQ Devel Docker Build

This image provides ManageIQ using the official Centos7 dockerhub build as a base along with PostgreSQL.

## Build

A typical build takes around 15 mins to complete.
It needs to be initiated from the root directory of the manageiq git repository

```
docker build -t manageiq .
```

It has been tested and validated under docker-1.10 (Fedora23) and 1.8.2 (Centos7)


## Run

### On standard distribution

The first time you run the container, it will initialize the database, **please allow 2-4 mins** for MIQ to respond.
```
docker run --privileged -di -p 3000:3000 -p 4000:4000 -p 5900-5999:5900-5999 manageiq
```
please note you can ommit some ports from the run command if you don't need to use them


### On Atomic host

```
atomic install -n <name> manageiq
atomic run -n <name> manageiq
atomic stop -n <name>  manageiq
atomic uninstall -n <name> manageiq
```


## Pull and use latest image from Docker Hub

TBD

## Access
The web interface is exposed at port 3000. Default login credentials.

Point your web browser to :

```
http://<your-ip-address>:3000
```

For console access, please use docker exec from docker host :
```
docker exec -ti <container-id> bash -l
```
