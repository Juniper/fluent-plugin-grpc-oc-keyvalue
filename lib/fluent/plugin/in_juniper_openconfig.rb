#
# Copyright (c) 2017 Juniper Networks, Inc. All rights reserved.
#


#require 'fluent/plugin/input'
require 'grpc'
#require 'multi_json'
require 'oc_services_pb'
require 'authentication_service_services_pb'
require 'json'
require 'socket'

module Fluent
    class OCInput < Input
        # Register Plugin
        Fluent::Plugin.register_input('juniper_openconfig', self)

        config_param :server, :array_param, :array, value_type: :string
        config_param :sensors, :array_param, :array, value_type: :string
        config_param :tag, :string, default: ''
        config_param :certFile, :string, default: ''
        config_param :username, :string, default: nil
        config_param :password, :string, default: ''
        config_param :sampleFrequency, :integer, default: 1000

        def configure(conf)
            super
            
            # Check if atleast one host is provided
            if @server.length == 0
                raise Fluent::ConfigError, "Atleast one server needs to be provided"
            end
            # Check if atleast one sensor is provided
            if @sensors.length == 0
                raise Fluent::ConfigError, "Atleast one sensor needs to be provided"
            end
            if not @tag == ''
                @tag = @tag + '.'
            end

        end

        def start
            super

            # Create a separate thread per host
            threads = []

            @server.each do |host|
                threads.push(Thread.new{start_host_threads(host)})
            end
        end

        def start_host_threads(host)
            while true do
                begin
                    log.debug "#{host}"
                    if @certFile != ''
                        log.debug "Using certificates to login for device #{host}"
                        creds = GRPC::Core::ChannelCredentials.new(File.read(@certFile))
                        stub = Telemetry::OpenConfigTelemetry::Stub.new(host, creds)
                    elsif @username != nil
                        log.debug "Using Password authentication for device #{host}"
                        
                        # Create channel
                        channel = GRPC::Core::Channel.new(host, {}, :this_channel_is_insecure)

                        # Authenticate the Channle
                        auth_stub, err = Authentication::Login::Stub.new(host, :this_channel_is_insecure, {channel_override: channel})
                        login_req = Authentication::LoginRequest.new(user_name: @username, password: @password, client_id: Socket.gethostname)
                        while true do
                            resp, _ = auth_stub.login_check(login_req)
                            if not resp.result
                                log.error "Password Authentication failed for #{host}. Will retry in 10 seconds"
                                sleep(10)
                                next
                            end
                            break
                        end

                        # Use the channel in OpenConfigTelemetry
                        stub, err = Telemetry::OpenConfigTelemetry::Stub.new(host, :this_channel_is_insecure, {channel_override: channel})
                    else
                        log.debug "Using no authentication for device #{host}"
                        stub = Telemetry::OpenConfigTelemetry::Stub.new(host, :this_channel_is_insecure)
                    end
                rescue Exception => e
                    log.error e.message
                    sleep(10)
                    next
                end

                threads = []
                host_name, host_port = host.split(':')
                begin
                    @sensors.each do |sensor|
                        frequency = @sampleFrequency
                        sensor_split = sensor.split(' ')

                        # If only one sensor is defined with no measurement name and sample frequency
                        measurement_name = sensor_split[0]
                        
                        # If there are multiple atrributes in the sensor
                        if sensor_split.length > 1
                            measurement_name = nil
                            # Check if first element is an integer and if it is an integer consider it as sample frequency
                            if sensor_split[0].to_i.to_s == sensor_split[0]
                                frequency = sensor_split[0].to_i
                                sensor_split = sensor_split[1, sensor_split.length]
                            end
                            # Check if the first element(second element in actual list) starts with '/', if it starts with '/' then 
                            # measurement name is not defined, else it becomes the measurement name and the rest are sensors
                            if not sensor_split[0].start_with?('/')
                                measurement_name = sensor_split[0]
                                sensor_split = sensor_split[1, sensor_split.length]
                            end
                        end
                        sensor_split.each do |sensor_name|
                            if measurement_name == nil
                                threads.push(Thread.new{start_collection(stub, host_name, host_port, sensor_name, sensor_name, @tag, frequency)})
                            else
                                threads.push(Thread.new{start_collection(stub, host_name, host_port, measurement_name, sensor_name, @tag, frequency)})
                            end
                        end
                    end
                    threads.each do |thread|
                        thread.join
                    end
                rescue Exception => e
                    log.error e.message
                    sleep(10)
                    next
                end
            end            
        end
        
        def start_collection(stub, host, port, measurement_name, sensor, tag, frequency)
            tag = tag + measurement_name
            req = ''
            resp = ''
            count = ENV['MOCHA_COUNT']
            if count != nil
                count = count.to_i
            end

            loop do
                if count != nil
                    if count <= 0
                        break
                    end
                end
                begin
                    # Create a stub to connect to the device
                    log.debug "Subsribing to #{sensor} with host #{host} on port #{port}"
                
                    # Create a Path (Sensor) list that needs to be subscribed
                    path_list = [Telemetry::Path.new(path: sensor, sample_frequency: frequency)]
                    # Create Subscription request
                    begin
                        req = Telemetry::SubscriptionRequest.new(path_list: path_list)
                    rescue Exception => e
                        log.error e.message
                        log.error e.backtrace.inspect
                        sleep(10)
                        next
                    end
                    # Subscribe using the subscription request
                    resp = ''
                    begin
                        log.debug "Sending subscription request for #{sensor} to host #{host} on port #{port}"
                        log.debug "Data from this subscription will be stored in #{tag}"
                        resp = stub.telemetry_subscribe(req)
                    rescue Exception => e
                        log.error e.message
                        log.error e.backtrace.inspect
                        sleep(10)
                        next
                    end
                    log.debug "Subscription done"
                    value_map = {
                        'uint_value': 'uintValue', 
                        'double_value': 'doubleValue', 
                        'int_value': 'intValue', 
                        'sint_value': 'sintValue', 
                        'bool_value': 'boolValue', 
                        'str_value': 'strValue', 
                        'bytes_value': 'bytesValue'
                    }
                    
                    # Start listening to the stream
                    resp.each do |data|
                        log.debug "======================================================="
                        log.debug "system_id : #{data.system_id}"
                        log.debug "component_id : #{data.component_id}"
                        log.debug "sub_component_id : #{data.sub_component_id}"
                        log.debug "path : #{data.path}" 
                        log.debug "sequence_number : #{data.sequence_number}"
                        time = epoc_to_sec(data.timestamp)
                        log.debug "timestamp : #{time}"
                        log.debug JSON.parse(data.to_json)
                        log.debug "======================================================="
                        time = epoc_to_sec(data.timestamp)

                        record = {}
                        prefix = ""
                        data.kv.each do |kv|
                            value = JSON.parse(kv.to_json)[value_map[kv.value]]
                            if kv.key == "__prefix__" and value != ""
                                prefix = value
                                next
                            elsif kv.key.start_with?('__')
                                next
                            end
                            record[prefix + kv.key] = value
                        end
                        record = transform_record(record, host)
                        
                        record.each do |key, value|
                            log.debug "Emitting #{value}"
                            router.emit(tag, time, value)
                        end
                    end
                    if count != nil
                        count -= 1
                    end
                rescue Exception => e
                    log.error e.message
                    log.error e.backtrace.inspect
                    sleep(10)
                    next
                end
            end
        end

        def epoc_to_sec(epoc) 
            # Check if sec, usec or msec
            nbr_digit = epoc.to_s.size
            
            if nbr_digit == 10
                return epoc.to_i
            elsif nbr_digit == 13
                return (epoc.to_i/1000).to_i
            elsif nbr_digit == 16
                return (epoc.to_i/1000000).to_i
            end

            return epoc
        end
        
        def transform_record(record, device)
            # Transforms the input record to a new hash which can be used with 
            # flunetd's InfluxDB output plugin
            
            tr_record = {}
            count = 0
            host = Socket.gethostname
            
            record.each do |master_key, value|
                # Get all the patterns in the key which indicates tags such as [name=ge/0/0/0]
                splits = master_key.scan(/\s*\[[^\]]*\]\s*/)
                # If there are no such tags then no tranformation is required
                if splits.length == 0
                    if not tr_record.key?('sp_key')
                        tr_record['sp_key'] = {}
                        tr_record['sp_key']['device'] = device
                        tr_record['sp_key']['host'] = host
                    end
                    tr_record['sp_key'][master_key] = value
                    count += 1
                    next
                end
                # Below code is when there are some tags found
                new_key = master_key
                # Create a unique key to for a bucket
                sp_key = splits.join(',')
                # Iterate over all the tags, split the master_key and form new tags and values
                splits.each do |split|
                    split_key = new_key.split(split)
                    new_key = split_key.join()
                    sub_key, sub_value = split.match(/^\s*\[\s*'*"*(.*?)"*'*\s*=\s*'*"*(.*?)"*'*\s*\]\s*$/).captures
                    sub_key = split_key[0] + '/@' + sub_key
                    if not tr_record.key?(sp_key)
                        tr_record[sp_key] = {}
                    end
                    tr_record[sp_key][sub_key] = sub_value
                end
                tr_record[sp_key][new_key] = value
                tr_record[sp_key]['device'] = device
                tr_record[sp_key]['host'] = host
                count += 1
            end
            
            return tr_record
        end

        # This method is called when shutting down.
        def shutdown
            # my own shutdown code
            super
        end
    end
end

