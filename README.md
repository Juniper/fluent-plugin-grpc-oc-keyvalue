# fluent-plugin-grpc-oc-keyvalue

## Overview

This plugin is designed to parse the Juniper OC telmetry data.
Juniper OC sensor data are sent as key/value paris over a gRPC session.
Collector needs to establish a gRPC session to the device and subscribe to the sensors for which it is intrested in. Once the subscription is successful, device will stream the subscribed sensor data at a frequency specified in the subscription message.

Below are few points that are considered

* One gRPC session is maintained per router per pipeline
* Retry mechanism in case the gRPC session is not established or terminated until the session is established or configurations are changed
* Support for username/password and SSL based authentication
* Addition of new sensors in future JUNOS versions, can be parsed without any changes to the plugin as long as present “oc.proto” is not changed
* Every entry on a particular timestamp is recognized based on the tags/keys. Tags are identified by parsing the xml path in the OC key attribute. For example, XML path “/interfaces/interface[name=ge-0/0/0]/state/admin-status” will result in a tag ““/interfaces/interface/@name” set to ge-0/0/0 and a field “/interfaces/interface/state/admin-status” set to a value in OC value attribute
* Multiple fields for a particular key set at a particular timestamp are combined to a single entry
* Timestamp, system id from the JTI message and hostname on which the collector is running will be added to all the entries


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
```

## TODO

Pull requests are very welcome!!

## Copyright

Copyright :  Copyright (c) 2017 Juniper Networks, Inc. All rights reserved.

License   :  Apache License, Version 2.0
