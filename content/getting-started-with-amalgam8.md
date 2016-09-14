# Getting Started with Amalgam8

Running your application on top of the Amalgam8 microservice platform
involves two main steps: (a) setting up the control plane services
(Amalgam8 service registry and Amalgam8 route controller), and (b) using the
Amalgam8 sidecar for communication between microservices instead of direct
microservice-to-microservice communication. 

The control plane setup, i.e., step (a) is needed only if you are running
Amalgam8 locally. If Amalgam8 control plane is provided as a service, you
need to obtain the URLs and authentication tokens for the controller and
the registry.

The Amalgam8 sidecar enables intelligent request routing while automating
service registration, discovery, and client-side load-balancing. The
Amalgam8 sidecar is based on Go+Nginx and follows an architecture similar
to
[Netflix Prana sidecar](http://techblog.netflix.com/2014/11/prana-sidecar-for-your-netflix-paas.html)
or
[AirBnB Smartstack](http://nerds.airbnb.com/smartstack-service-discovery-cloud/).


## TL;DR

* Start the control plane services (Amalgam8 Controller and Registry)

    ```bash
    #registry
    docker run -d amalgam8/a8-registry
    #controller
    docker run -d amalgam8/a8-controller
    ```


* Install the Amalgam8 CLI (`a8ctl`)

    ```bash
    sudo pip install git+https://github.com/amalgam8/a8ctl
    ```


* Install the sidecar in your Dockerized microservice (assuming you have
  `curl` pre-installed)

    ```Dockerfile
    RUN curl -sSL https://github.com/amalgam8/amalgam8/releases/download/${VERSION}/a8sidecar.sh | sh
    ```


* Launch your app via the sidecar

    ```Dockerfile
    ENTRYPOINT ["a8sidecar", "--proxy", "--register", "--supervise", "YOURAPP", "YOURAPP_ARG", "YOURAPP_ARG"]
    ```

* Inject environment variables into your container

    ```bash
    A8_SERVICE=service_name:service_tags
    A8_ENDPOINT_PORT=port_where_service_is_listening
    A8_ENDPOINT_TYPE=http|https
    A8_REGISTRY_URL=http://a8registryURL
    A8_CONTROLLER_URL=http://a8controllerURL
    ```

* Make API calls to other microservices via the sidecar [http://localhost:6379/serviceName/endpoint]()

* Control traffic to microservices using the control plane API or the
   [a8ctl](https://github.com/amalgam8/a8ctl) utility

    ```bash
    a8ctl route-set serviceName --default v1 --selector 'v2(user="Alice")' --selector 'v3(user="Bob")'
    ```


## 1. Integrating the sidecar into your application

The sidecar is independent of your application process. The communication
model between a microservice, its sidecar and the target microservice is
shown below:

![Communication between app and sidecar](figures/amalgam8-sidecar-communication-model.svg)

When you want to make API calls to other microservices from your
application, you should call the sidecar at localhost:6379. 
The format of the API call is
[http://localhost:6379/serviceName/endpoint]()

where the `serviceName` is the service name that was used when launching
the target microservice (the `A8_SERVICE` environment variable), and the
endpoint is the API endpoint exposed by the target microservice.

For example, to invoke the `getItem` API in the `catalog` microservice,
your microservice would simply invoke the API via the URL:
[http://localhost:6379/catalog/getItem?id=123]().

Note that service versions are not part of the URL. The choice of the
service version (e.g., catalog:v1, catalog:v2, etc.), will be done
dynamically by the sidecar, based on routing rules set by the Amalgam8
controller.

The following subsections describe how to integrate the sidecar into an
application running in a Docker container (applicable for Docker Swarm,
Marathon) and in a Kubernetes pod.


### Single Docker container <a id="int-docker"></a>

Add the following line to your `Dockerfile` to install the sidecar in your
docker container either using `curl`

```Dockerfile
RUN curl -sSL https://github.com/amalgam8/amalgam8/releases/download/${VERSION}/a8sidecar.sh | sh
```

or using `wget`

```Dockerfile
RUN wget -qO- https://github.com/amalgam8/amalgam8/releases/download/${VERSION}/a8sidecar.sh | sh
```

Replace ${VERSION} with the specific version of Amalgam8 you would
like. The set of releases are available [here](https://github.com/amalgam8/amalgam8/releases).

**Optional app supervision:** If you do not have a startup script in your
container, i.e., you are running only a single application, the sidecar can
also serve as a supervisor process that automatically starts up your
application. When the application dies, the sidecar exits with the same
exit code as the application, causing the container to terminate as well.

To use the sidecar to manage your application, add the following lines to your
`Dockerfile`

```Dockerfile
ENTRYPOINT ["a8sidecar", "--proxy", "--register", "--supervise", "YOURAPP", "YOURAPP_ARG", "YOURAPP_ARG"]
```

If you wish to manage the application process by yourself, then make sure
to launch the sidecar in the background when starting the docker
container. The environment variables required to run the sidecar are
described in detail [below](#runtime).

### Kubernetes Pods <a id="int-kube"></a>

With Kubernetes, the sidecar can be run as a standalone container in the
same `Pod` as your application container. No changes are needed to the
application's Dockerfile. Modify your service's YAML file to launch the
sidecar as another container in the same pod as your application
container. The latest version of the sidecar is available in Docker Hub in
two formats:

*  `amalgam8/a8-sidecar` - ubuntu-based version
*  `amalgam8/a8-sidecar:alpine` - alpine linux based version

## 2. Configuring the sidecar <a id="runtime"></a>

The following instructions apply to both Docker-based and Kubernetes-based
installations. Configuration options can be set via environment variables,
command line flags, or YAML configuration files.  Order of precedence is
command line flags first, then environmenmt variables, configuration files,
and lastly default values.

| Environment Variable | Flag Name                   | YAML Key | Description | Default Value |Required|
|:---------------------|:----------------------------|:---------|:------------|:--------------|--------|
| A8_CONFIG | --config | | Path to a file to load configuration from | | no |
| A8_LOG_LEVEL | --log_level | log_level | Logging level (debug, info, warn, error, fatal, panic) | info | no |
| A8_SERVICE | --service | service.name & service.tags | service name to register with, optionally followed by a colon and a comma-separated list of tags | | yes |
| A8_ENDPOINT_HOST | --endpoint_host | endpoint.host | service endpoint IP or hostname. Defaults to the IP (e.g., container) where the sidecar is running | optional |
| A8_ENDPOINT_PORT | --endpoint_port | endpoint.port | service endpoint port |  | yes |
| A8_ENDPOINT_TYPE | --endpoint_type | endpoint.type | service endpoint type (http, https, udp, tcp, user) | http | no |
| A8_REGISTER | --register | register | enable automatic service registration and heartbeat | false | See note above |
| A8_PROXY | --proxy | proxy | enable automatic service discovery and load balancing across services using NGINX | false | See note above |
| A8_LOG | --log | log | enable logging of outgoing requests through proxy using FileBeat | false | no |
| A8_SUPERVISE | --supervise | supervise | Manage application process. If application dies, sidecar process is killed as well. All arguments provided after the flags will be considered as part of the application invocation | false | no |
| A8_REGISTRY_URL | --registry_url | registry.url | registry URL |  | yes if `-register` is enabled |
| A8_REGISTRY_TOKEN | --registry_token | registry.token | registry auth token | | yes if `-register` is enabled and an auth mode is set |
| A8_REGISTRY_POLL | --registry_poll | registry.poll | interval for polling Registry | 15s | no |
| A8_CONTROLLER_URL | --controller_url | controller.url | controller URL |  | yes if `-proxy` is enabled |
| A8_CONTROLLER_TOKEN | --controller_token | controller.token | Auth token for Controller instance |  | yes if `-proxy` is enabled and an auth mode is set |
| A8_CONTROLLER_POLL | --controller_poll | controller.poll | interval for polling Controller | 15s | no |
| A8_LOGSTASH_SERVER | --logstash_server | logstash_server | logstash target for nginx logs |  | yes if `-log` is enabled |
|  | --help, -h | show help | | |
|  | --version, -v | print the version | | |

### Configuration precedence

**Example configuration file**:

```yaml
register: true
proxy: true

service:
  name: helloworld
  tags: 
    - v1
    - somethingelse
  
endpoint:
  host: 172.10.10.1
  port: 9080
  type: https

registry:
  url:   http://registry:8080
  token: abcdef
  poll:  10s
  
controller:
  url:   http://controller:8080
  token: abcdef
  poll:  30s
  
supervise: true
app: [ "python", "helloworld.py ]

log: true
logstash_server: logstash:8092

log_level: debug
```


### Configurations Options

**Automatic service registration:** Registration and heartbeat with the
Amalgam8 service registry can be enabled by setting the following
environment variables or setting the equivalent fields in the config file:

```bash
A8_REGISTER=true
A8_REGISTRY_URL=http://a8registryURL
A8_SERVICE=service_name:service_version_tag
A8_ENDPOINT_PORT=port_where_service_is_listening
A8_ENDPOINT_TYPE=http|https|tcp|udp|user
```

**Intelligent Request Routing:** For microservices that make outbound calls
to other microservices, service discovery and client-side load balancing,
version and content-based routing can be enabled by the following options:

```bash
A8_PROXY=true
A8_CONTROLLER_URL=http://a8controllerURL
```

**Logging:** All logs pertaining to external API calls made by the Nginx
proxy will be stored in `/var/log/nginx/a8_access.log` and
`/var/log/nginx/error.log`. The access logs are stored in JSON format. Note
that there is **no support for log rotation**. If you have a monitoring and
logging system in place, it is advisable to propagate the request logs to
your log storage system in order to take advantage of Amalgam8 features
like resilience testing.

The sidecar installation comes preconfigured with
[Filebeat](https://www.elastic.co/products/beats/filebeat) that can be
configured automatically to ship the Nginx access logs to a Logstash
server, which in turn propagates the logs to elasticsearch. If you wish to
use the filebeat system for log processing, make sure to have Elasticsearch
and Logstash services available in your application deployment. The
following two environment variables enable the filebeat process:

```bash
A8_LOG=true
A8_LOGSTASH_SERVER='logstash_server:port'
```

**Note 1:** The logstash environment variable needs to be enclosed in single
quotes.

**Note 2:** You can omit the logstash server details if you override the
`filebeat.yml` file to log directly to Elasticsearch. The `filebeat.yml`
file can be found in `/etc/filebeat/filebeat.yml`.
