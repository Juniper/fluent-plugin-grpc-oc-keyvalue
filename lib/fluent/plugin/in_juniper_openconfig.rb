#require 'fluent/plugin/input'
require 'grpc'
#require 'multi_json'
require 'oc_services_pb'
require 'json'
require 'socket'

module Fluent
    class OCInput < Input
        # Register Plugin
        Fluent::Plugin.register_input('juniper_openconfig', self)

        config_param :hosts, :array_param, :array, value_type: :string
        config_param :port, :integer, default: 32767
        config_param :sensors, :array_param, :array, value_type: :string
        config_param :tag, :string, default: ''
        config_param :cert_file, :string, default: ''

        def configure(conf)
            super
            
            # Check if atleast one host is provided
            if @hosts.length == 0
                raise Fluent::ConfigError, "Atleast one host needs to be provided"
            end
            # Check that the port provided is not one of well known ports
            if @port < 1024
              raise Fluent::ConfigError, "well known ports cannot be used for this purpose."
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
            
            # Create a separate thread per host and per sensor
            threads = []
            @hosts.each do |host|
                if @cert_file == ''
                    stub, err = Telemetry::OpenConfigTelemetry::Stub.new(host + ':' + port.to_s, :this_channel_is_insecure)
                else
                    creds = GRPC::Core::ChannelCredentials.new(File.read(@cert_file))
                    stub, err = Telemetry::OpenConfigTelemetry::Stub.new(host + ':' + port.to_s, creds)
                end                
                @sensors.each do |sensor|
                    #start_collection(server, port, sensor)
                    threads.push(Thread.new{start_collection(stub, host, @port, sensor, @tag)})
                end
            end
            threads.each do |thread|
                thread.join
            end
        end

        def start_collection(stub, host, port, sensor, tag)
            tag = tag + '.' + sensor
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
                    path_list = [Telemetry::Path.new(path: sensor, sample_frequency: 1000)]
                    # Create Subscription request
                    begin
                        req = Telemetry::SubscriptionRequest.new(path_list: path_list)
                    rescue Exception => e
                        log.error e.message
                        log.error e.backtrace.inspect
                        next
                    end
                    # Subscribe using the subscription request
                    resp = ''
                    begin
                        resp = stub.telemetry_subscribe(req)
                    rescue Exception => e
                        log.error e.message
                        log.error e.backtrace.inspect
                        next
                    end
                    
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

