# test/plugin/test_in_your_own.rb

require 'test/unit'
require 'mocha/test_unit'
#require 'fluent/test/driver/input'
require 'fluent/test'

# your own plugin
require 'in_juniper_openconfig'

class OCInputTest < Test::Unit::TestCase
    def setup
        Fluent::Test.setup  # this is required to setup router and others
    end

    # default configuration for tests
     CONFIG = %Q(
        hosts ["asd"]
        sensors ["asdasd"]
    )

    def create_driver(conf = CONFIG)
        #Fluent::Test::Driver::Input.new(Fluent::Plugin::in_juniper_openconfig).configure(conf)
        #Fluent::Test::InputTestDriver.new(Fluent::Plugin::OCInput).configure(conf)
        Fluent::Test::InputTestDriver.new(Fluent::OCInput).configure(conf)
        #Fluent::Test::Driver::Input.new(Fluent::Plugin::OCInput).configure(conf)
    end
    
    sub_test_case 'configured with invalid configurations' do
        test 'hosts should reject an empty list' do
            #d = create_driver
            assert_raise Fluent::ConfigError do
                create_driver(%[
                    hosts []
                ])
            end
        end
        test 'sensors should reject an empty list' do
            assert_raise Fluent::ConfigError do
                create_driver(%Q(
                    hosts ["rtr1"]
                    servers []
                ))
            end
        end
    end

    sub_test_case 'Checking optional default values' do
        test 'port default value is set to 32767' do
            d = create_driver
            assert_equal 32767, d.instance.port
        end
        test 'tag default value is set to empty string' do
            d = create_driver
            assert_equal "", d.instance.tag
        end
        test 'cert_file default value is set to empty string' do
            d = create_driver
            assert_equal "", d.instance.cert_file
        end
    end

    def test_epoc_to_sec
        #oc = Fluent::Input::OCInput.new
        oc = Fluent::OCInput.new
        assert_equal 149699841, oc.epoc_to_sec(149699841)
        assert_equal 1496998418, oc.epoc_to_sec(1496998418)
        assert_equal 1496998418, oc.epoc_to_sec(1496998418000)
        assert_equal 1496998418, oc.epoc_to_sec(1496998418000000)
    end
    def test_transform_record
        #oc = Fluent::Plugin::OCInput.new
        oc = Fluent::OCInput.new
        Socket.stubs(:gethostname => 'TestHost')

        # No sub keys
        record = {}
        record["key1"] = "value1"
        tr_record = {}
        tr_record["sp_key"] = {}
        tr_record["sp_key"]["device"] = "rtr1" 
        tr_record["sp_key"]["host"] = "TestHost"
        tr_record["sp_key"]["key1"] = "value1"
        assert_equal tr_record, oc.transform_record(record, 'rtr1')

        # With a single subkey sub keys
        record = {}
        record["key1[name=sub_key]/leaf1"] = "value1"
        record["key1[name=sub_key]/leaf2"] = "value2"
        sp_key = "key1[name=sub_key]/leaf".scan(/\s*\[[^\]]*\]\s*/).join(',')
        tr_record = {}
        tr_record[sp_key] = {}
        tr_record[sp_key]["key1/@name"] = "sub_key"
        tr_record[sp_key]["key1/leaf1"] = "value1"
        tr_record[sp_key]["key1/leaf2"] = "value2"
        tr_record[sp_key]["device"] = "rtr1"
        tr_record[sp_key]["host"] = "TestHost"
        assert_equal tr_record, oc.transform_record(record, 'rtr1')

        # with multiple subkeys
        record = {}
        record["key1[name=sub_key1]/key2[name=sub_key2]/leaf1"] = "value1"
        record["key1[name=sub_key1]/key2[name=sub_key2]/leaf2"] = "value2"
        sp_key = "key1[name=sub_key1]/key2[name=sub_key2]/leaf2".scan(/\s*\[[^\]]*\]\s*/).join(',')
        tr_record = {}
        tr_record[sp_key] = {}
        tr_record[sp_key]["key1/@name"] = "sub_key1"
        tr_record[sp_key]["key1/key2/@name"] = "sub_key2"
        tr_record[sp_key]["key1/key2/leaf1"] = "value1"
        tr_record[sp_key]["key1/key2/leaf2"] = "value2"
        tr_record[sp_key]["device"] = "rtr1"
        tr_record[sp_key]["host"] = "TestHost"
        assert_equal tr_record, oc.transform_record(record, 'rtr1')
    end

    #def test_start_collection
    sub_test_case 'Start Collection' do
        test 'Start Collection 1' do
            d = create_driver(%Q(
                hosts ["127.0.0.1"]
                sensors ["aaa"]
            ))
            #oc = Fluent::Plugin::OCInput.new
            oc = Fluent::OCInput.new
            
            ENV['MOCHA_COUNT'] = '1'
            #stub = Telemetry::OpenConfigTelemetry::Stub.stubs(:new => mock())
            res = mock()
            res.stubs(:system_id).returns('')
            res.stubs(:component_id).returns('component_id')
            res.stubs(:sub_component_id).returns('sub_component_id')
            res.stubs(:path).returns('path')
            res.stubs(:sequence_number).returns('sequence_number')
            res.stubs(:timestamp).returns('timestamp')
            #resp[0].stubs(:kv).returns('')
            json = {"key"=>"__timestamp__", "strValue"=>"1497431542576"}
            #{"key"=>"__junos_re_stream_creation_timestamp__", "uintValue"=>1497431542015},
            #{"key"=>"__junos_re_payload_get_timestamp__", "uintValue"=>1497431542575},
            #{"key"=>"__prefix__", "strValue"=>"/components/component[name='Routing Engine1']/"},
            #{"key"=>"properties/property[name='mastership-priority']/name", "strValue"=>"mastership-priority"},
            #{"key"=>"properties/property[name='mastership-priority']/state/value", "strValue"=>"Backup (default)"},
            #{"key"=>"properties/property[name='temperature']/name", "strValue"=>"temperature"},
            #{"key"=>"properties/property[name='temperature']/state/value", "strValue"=>"33"},
            #{"key"=>"properties/property[name='temperature-cpu']/name", "strValue"=>"temperature-cpu"},
            #{"key"=>"properties/property[name='temperature-cpu']/state/value", "strValue"=>"32"},
            #{"key"=>"properties/property[name='cpu-utilization-user']/name", "strValue"=>"cpu-utilization-user"},
            #{"key"=>"properties/property[name='cpu-utilization-user']/state/value", "strValue"=>"0"},
            #{"key"=>"properties/property[name='cpu-utilization-background']/name", "strValue"=>"cpu-utilization-background"},
            #{"key"=>"properties/property[name='cpu-utilization-background']/state/value", "strValue"=>"0"},
            #{"key"=>"properties/property[name='cpu-utilization-kernel']/name", "strValue"=>"cpu-utilization-kernel"},
            #{"key"=>"properties/property[name='cpu-utilization-kernel']/state/value", "strValue"=>"0"},
            #{"key"=>"properties/property[name='cpu-utilization-interrupt']/name", "strValue"=>"cpu-utilization-interrupt"},
            #{"key"=>"properties/property[name='cpu-utilization-interrupt']/state/value", "strValue"=>"0"},
            #{"key"=>"properties/property[name='cpu-utilization-idle']/name", "strValue"=>"cpu-utilization-idle"},
            #{"key"=>"properties/property[name='cpu-utilization-idle']/state/value", "strValue"=>"99"},
            #{"key"=>"properties/property[name='memory-dram-used']/name", "strValue"=>"memory-dram-used"},
            #{"key"=>"properties/property[name='memory-dram-used']/state/value", "strValue"=>"3313"},
            #{"key"=>"properties/property[name='memory-dram-installed']/name", "strValue"=>"memory-dram-installed"},
            #{"key"=>"properties/property[name='memory-dram-installed']/state/value", "strValue"=>"8192"}]
            kv = []
            t_kv = mock()
            t_kv.stubs(:key).returns('__prefix__')
            t_kv.stubs(:value).returns("str_value")
            kv.push(t_kv)
            t_kv.stubs(:key).returns("properties/property[name='memory-dram-installed']/state/value")
            t_kv.stubs(:value).returns("str_value")
            kv.push(t_kv)
            res.stubs(:kv).returns(kv)
            resp = [res]
            JSON.stubs(:parse).returns(json)
            stub, err = Telemetry::OpenConfigTelemetry::Stub.new('127.0.0.1:32767', :this_channel_is_insecure)
            Telemetry::OpenConfigTelemetry::Stub.any_instance.stubs(:telemetry_subscribe).returns(resp)
            #d.run(expect_emits: 1, timeout: 10)
            d.run
            #assert_equal "", oc.start_collection(stub, 'rtr1', 32767, '/interfaces/', 'tag1')
        end
    end

#    sub_test_case 'plugin will emit some events' do
#        test 'test expects plugin emits events 4 times' do
#            d = create_driver(%Q(
#                hosts ["127.0.0.1"]
#                sensors ["aaa"]
#            ))
#            
#            time = 1496998418
#            data = [
#                {tag: "tag1", message: {"t" => time, "v" => {"a"=>1}}},
#                {tag: "tag2", message: {"t" => time, "v" => {"a"=>1}}},
#                {tag: "tag3", message: {"t" => time, "v" => {"a"=>32}}},
#            ]
#            puts data
#            d.run(expect_emits: 3, timeout: 1) do
#                puts data
#                data.each do |record|
#                end
#            end
            # this method blocks until input plugin emits events 4 times
            # or 10 seconds passes
            
            #events = d.events # array of [tag, time, record]
            #assert_equal "expected_tag", events[0][0]
#        end
#    end

end
