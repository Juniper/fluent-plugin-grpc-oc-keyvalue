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

* Configuration with one device and one sensor:

    - In below configuration sample frequency is set to 5000ms and the data is stored in 'junoper.oc./interfaces/' table.
    - Authentication used here is SSL based

```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    server ["device-a:12345"]
    sensors ["/interfaces/"]
    certFile "/tmp/cert.pem"
    @log_level debug
</source>
```

* Configuration with one device and multiple sensors:

    - With below configuration data from '/interfaces/' sensor is stored in 'junoper.oc./interfaces/' table and data from '/components/' will be stored in 'junoper.oc./components/' table.
    - Authentication used here is Password based
    
```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    server ["device-a:12345"]
    sensors ["/interfaces/", "/components/"]
    certFile "/tmp/cert.pem"
    @log_level debug
</source>
```

* Configuration with multiple devices and multiple sensros with different non default ferequency:

    - With below configuration, two sensors '/interfaces' and '/components/' will be subsscribed to devices device-a and device-b.
    - gRPC connection is made on port '12345' for device 'device-a' and for device 'device-b' connection is made on port '23456'.
    - '/interfaces' will be subscribed with a frequency of 6 seconds
    - '/components/' will be subscribed with a frequency of 7 seconds
    - Data from sensor '/interfaces/' from both the devices will be stored in table 'junoper.oc./interfaces/'
    - Data from sensor '/components/' from both the devices will be stored in table 'junoper.oc./components/'

```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    server ["device-a:12345, "device-b:23456"]
    sensors ["6000 /interfaces/", "7000 /components/"]
    certFile "/tmp/cert.pem"
    @log_level debug
</source>
```

* Configuration with multiple sensors with same frequency under same table

    - '/interfaces' will be subscribed with a frequency of 6 seconds
    - '/components/' will be subscribed with a frequency of 7 seconds
    - '/ospf/' and '/isis/' will be subscribed with a frequency of 6 seconds
    - Data from sensor '/interfaces/' from both the devices will be stored in table 'junoper.oc./interfaces/'
    - Data from sensor '/components/' from both the devices will be stored in table 'junoper.oc./components/'
    - Data from sensors '/ospf/' and '/isis/' from both the devices will be stored in table 'juniper.oc.collection'

```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    server ["device-a:12345, "device-b:23456"]
    sensors ["6000 /interfaces/", "7000 /components/", "5000 collection /ospf/ /isis/"]
    certFile "/tmp/cert.pem"
    @log_level debug
</source>
```

## TODO

Pull requests are very welcome!!

## Copyright

Copyright :  Copyright (c) 2017 Juniper Networks, Inc. All rights reserved.

License   :  Apache License, Version 2.0
