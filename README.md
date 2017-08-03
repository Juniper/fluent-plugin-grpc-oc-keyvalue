OpenConfig Telemetry Input Plugin

The plugin reads OpenConfig telemetry data from listed sensors. Refer to
[openconfig.net](http://openconfig.net/) for more details.

### Configuration:

```toml
<source>
    @type juniper_openconfig
    tag juniper.oc
    hosts ["device-a"] #[REQUIRED] Device names as list
    sensors ["/components/", "/interfaces/"] #[REQUIRED] Sensoirs as list
    port 12345 #[OPTIONAL] Port number to which grpc connection needs to be established. Default port is 32767
    cert_file "/tmp/cert.pem"  #[OPTIONAL] Certificate file for authentication. In-secure connection is established if the certificate is not provided
    @log_level debug
</source>



