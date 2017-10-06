OpenConfig Telemetry Input Plugin

The plugin reads OpenConfig telemetry data from listed sensors. Refer to
[openconfig.net](http://openconfig.net/) for more details.

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



