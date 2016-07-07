## What is Amalgam8

Amalgam8 is a multi-tenant platform for quickly building
[microservice applications](http://martinfowler.com/articles/microservices.html)
and managing the DevOps lifecycle aspects of various microservices.
Its goals are to simplify integration of polyglot microservices and help
developers accomplish DevOps tasks such as
[A/B testing](https://www.optimizely.com/ab-testing/),
[canary releases](http://martinfowler.com/bliki/CanaryRelease.html),
red/black deployments,
[resilience testing](https://developer.ibm.com/open/2016/06/06/systematically-resilience-testing-of-microservices-with-gremlin/),
etc.

The Amalgam8 platform achieves these goals through two stages. First, a
language-agnostic sidecar process enables developers to quickly integrate
polyglot microservices by abstracting away service registration, discovery,
load-balancing from the application process.

Second, a centralized control plane programs the sidecars at runtime to
control traffic across different versions of microservices
(both edge and mid-tier), and manipulate/transform requests based on various
rule. Using the control plane APIs, developers can
easily perform tasks such as canary releases, red/black deployments,
version-aware routing, A/B testing, failure recovery testing (resilience
testing), etc.

![high-level architecture](figures/amalgam8-architecture.svg)

Due to its native support for multi-tenancy, the Amalgam8 control plane can
be easily integrated into any multi-tenant infrastructure (e.g., IBM
Bluemix, AWS, Azure, etc.), thereby providing application developers with a
consistent interface for building and managing their microservice
applications across different providers.

The Amalgam8 platform can run on any compute infrastructure such as
containers, VMs or even bare metal. It easily integrates with popular
container management solutions such as Docker Swarm, Kubernetes,
Marathon/Mesos. In addition, it can run on various public cloud
infrastructures such as IBM Bluemix, Google Cloud Platform, etc.
