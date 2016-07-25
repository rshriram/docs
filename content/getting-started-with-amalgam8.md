## Getting Started with Amalgam8

Running your application on top of the Amalgam8 microservice platform
involves two main steps: (a) setting up the control plane services
(Amalgam8 service registry and Amalgam8 controller), and (b) using the
Amalgam8 sidecar for communication between microservices instead of direct
microservice-to-microservice communication

The Amalgam8 sidecar is a lightweight agent that automates service
registration and serves as an intelligent request router between
microservices. If you are familiar with
[Netflix Ribbon](https://github.com/Netflix/ribbon), think of the Amalgam8
sidecar as a language-independent version of Ribbon, running in a separate
process alongside your microservices.

### TL;DR

* Start the control plane services (Amalgam8 Controller and Registry)

    ```bash
    #registry
    docker run -d amalgam8/a8-registry -auth_mode=trusted
    #controller
    docker run -d amalgam8/a8-controller -poll_interval=5s
    ```


* Create a tenant in the control plane

    ```bash
    curl -H "Content-Type: application/json" -H "Authorization: <SECRET>" http://<controllerIP>:6379/v1/tenants -d '
     {
       "credentials": {
         "registry": {
            "url": "http://<registryIP>:8080",
            "token": "<SECRET>"
         }
       }
     }'
    ```


* Install the sidecar in your Dockerized microservice.

    ```Dockerfile
    RUN curl -sSL https://github.com/amalgam8/sidecar/releases/download/${VERSION}/install-a8sidecar.sh | sh
    ```


* Launch your app via the sidecar

    ```Dockerfile
    ENTRYPOINT ["a8sidecar", "--supervise", "YOURAPP", "YOURAPP_ARG", "YOURAPP_ARG"]
    ```


* Make API calls to other microservices via the sidecar [http://localhost:6379/serviceName/endpoint]()

* Control traffic to microservices using the control plane API or the
   [a8ctl](https://github.com/amalgam8/a8ctl) utility

    ```bash
    a8ctl route-set serviceName --default v1 --selector 'v2(user="Alice")' --selector 'v3(user="Bob")'
    ```


### 1. Integrating the sidecar into your application

#### Single Docker container <a id="int-docker"></a>

Add the following line to your `Dockerfile` to install the sidecar in your docker container:

```Dockerfile
RUN curl -sSL https://github.com/amalgam8/sidecar/releases/download/${VERSION}/install-a8sidecar.sh | sh
```

or

```Dockerfile
RUN wget -qO- https://github.com/amalgam8/sidecar/releases/download/${VERSION}/install-a8sidecar.sh | sh
```

where `${VERSION}` is the version of the sidecar that you wish to install.

**Optional app supervision:** The sidecar can serve as a supervisor process that
automatically starts up your application in addition to the Nginx proxy. To
use the sidecar to manage your application, add the following lines to your
`Dockerfile`

```Dockerfile
ENTRYPOINT ["a8sidecar", "--supervise", "YOURAPP", "YOURAPP_ARG", "YOURAPP_ARG"]
```

If you wish to manage the application process by yourself, then make sure
to launch the sidecar in the background when starting the docker
container. The environment variables required to run the sidecar are
described in detail [below](#runtime).

#### Kubernetes Pods <a id="int-kube"></a>

With Kubernetes, the sidecar can be run as a standalone container in the
same `Pod` as your application container. No changes are needed to the
application's Dockerfile. Modify your service's YAML file to launch the
sidecar as another container in the same pod as your application
container. The latest version of the sidecar is available in Docker Hub in
two formats:

*  `amalgam8/a8-sidecar` - ubuntu-based version
*  `amalgam8/a8-sidecar:alpine` - alpine linux based version

### 2. Starting the sidecar <a id="runtime"></a>

The following instructions apply to both Docker-based and Kubernetes-based
installations. There are two modes for running the sidecar:

<!-- #### Environment variables or CLI flags -->

<!-- An exhaustive list of configuration options can be found in the -->
<!-- [Configuration](#config) section. For a quick start, take a look at the -->
<!-- [examples apps](https://github.com/amalgam8/examples) to get an idea of the -->
<!-- required environment variables needed by Amalgam8. -->


#### With automatic service registration only <a id="regonly"></a>

For leaf nodes, i.e., microservices that make no outbound calls, only
service registration is required. Inject the following environment
variables while launching your application container in Docker or the
sidecar container inside kubernetes 

```bash
A8_PROXY=false
A8_REGISTER=true
A8_REGISTRY_URL=http://a8registryURL
A8_REGISTRY_TOKEN=a8registry_auth_token
A8_SERVICE=service_name:service_version_tag
A8_ENDPOINT_PORT=port_where_service_is_listening
A8_ENDPOINT_TYPE=http|https|tcp|udp|user
```

#### With automatic service registration, discovery & intelligent routing <a id="routing"></a>

For microservices that make outbound calls to other microservices, service
registration, service discovery and client-side load balancing,
version-aware routing are required.

```bash
A8_REGISTER=true
A8_REGISTRY_URL=http://a8registryURL
A8_REGISTRY_TOKEN=a8registry_auth_token
A8_SERVICE=service_name:service_version_tag
A8_SERVICE=service_name:service_version_tag
A8_ENDPOINT_PORT=port_where_service_is_listening
A8_ENDPOINT_TYPE=http|https|tcp|udp|user

A8_PROXY=true
A8_LOG=false
A8_CONTROLLER_URL=http://a8controllerURL
A8_TENANT_TOKEN=a8controller_auth_token
A8_CONTROLLER_POLL=polling_interval_between_sidecar_and_controller(5s)
```

**Update propagation: polling vs real-time**: By default, the sidecar will
periodically poll the Amalgam8 Controller for updates on registered
microservices, rules for routing requests to various microservices,
etc. For real-time update propagation, the Amalgam8 has the ability to
publish updates to a Kafka bus. If you have setup the Amalgam8 controller
with Kafka, add the following environment variable while launching your
microservices:

```bash
A8_KAFKA_BROKER=kafkahost1:kafkaport,kafkahost2:kafkaport
```

By default, Amalgam8 uses Kafka without any authentication. If you wish to
use Kafka with SASL, refer to the [configuration section](#config) for
details regarding the additional environment variables needed.

**Request logs**: All logs pertaining to external API calls made by
the Nginx proxy will be stored in `/var/log/nginx/a8_access.log` and
`/var/log/nginx/error.log`. The access logs are stored in JSON format. Note
that there is **no support for log rotation**. If you have a monitoring and
logging system in place, it is advisable to propagate the request logs to
your log storage system in order to take advantage of Amalgam8 features
like resilience testing.

The sidecar installation comes preconfigured with
[Filebeat](https://www.elastic.co/products/beats/filebeat) that can be
configured automatically to ship the access logs to a Logstash server,
which in turn propagates the logs to elasticsearch. If you wish to use the
filebeat system for log processing, make sure to have Elasticsearch and
Logstash services available in your application deployment. The following
two environment variables enable the filebeat process:

```bash
A8_LOG=true
A8_LOGSTASH_SERVER='logstash_server:port'
```

**Note:** The logstash environment variable needs to be enclosed in single quotes.

### 3. Using the sidecar

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
