# OpenConfig Telemetry Input Plugin

# fluent-plugin-grpc-oc-keyvalue

## Overview

This plugin is designed to parse the Juniper OC telmetry data.
Juniper OC sensor data key/value paris sent over a gRPC session.
Collector needs to establish a gRPC session to the device and subscribe to the sensors for which it is intrested in. Once the subscription is successful, device will stream the subscribed sensor data at a frequency specified in the subscription message.


## Installation

Download the plugin from `https://git.juniper.net/vijaygadde/fluent-plugin-grpc-oc-keyvalue`

Change directory to `<path-of-download>/fluent-plugin-grpc-oc-keyvalue`

Build using `gem build fluent-plugin-grpc-oc-keyvalue.gemspec`

Install using `gem install fluent-plugin-grpc-oc-keyvalue-0.0.1.gem`

### Configuration:

```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    server ["device-a:12345", "device-b:23456"] #[REQUIRED] Device list with port numbers
    sensors ["/components/", "4000 /interfaces/", "collection /lldp/ /mpls/", "5000 collection2 /ospf/ /isis/"] #[REQUIRED] Sensoirs as list
    certFile "/tmp/cert.pem"  #[OPTIONAL] Certificate file for authentication. In-secure connection is established if the certificate is not provided
    username "user1" #[OPTIONAL]
    password "password1" #[OPTIONAL]
    @log_level debug
</source>



