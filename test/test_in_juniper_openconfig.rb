# test/plugin/test_in_your_own.rb

require 'simplecov'
SimpleCov.start do
    add_filter %r{lib/.*pb}
end

require 'test/unit'
require 'mocha/test_unit'
#require 'fluent/test/driver/input'
require 'fluent/test'
require 'grpc'

# your own plugin
require 'fluent/plugin/in_juniper_openconfig'
require 'authentication_service_pb.rb'
require 'oc_services_pb'
require 'oc_pb.rb'

class OCInputTest < Test::Unit::TestCase
    def setup
        Fluent::Test.setup  # this is required to setup router and others
    end

    # default configuration for tests
     CONFIG = %Q(
        server ["asd"]
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
                    servers []
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
        test 'tag default value is set to empty string' do
            d = create_driver
            assert_equal "", d.instance.tag
        end
        test 'cert_file default value is set to empty string' do
            d = create_driver
            assert_equal "", d.instance.certFile
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

    sub_test_case 'Start Collection' do
        test 'Start Collection 1' do
            d = create_driver(%Q(
                server ["127.0.0.1"]
                sensors ["aaa"]
            ))
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
            json = {"key"=>"__timestamp__", "strValue"=>"1497431542576"}
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
            #stub, err =  Telemetry::Path::Stub.new('/interfaces/', 5000)
            #Telemetry::Stub.any_instance.stubs(:Path)

            stub, err = Telemetry::OpenConfigTelemetry::Stub.new('127.0.0.1:32767', :this_channel_is_insecure)
            Telemetry::OpenConfigTelemetry::Stub.any_instance.stubs(:telemetry_subscribe).returns(resp)
            #d.run(expect_emits: 1, timeout: 10)
            d.run
            #assert_equal "", oc.start_collection(stub, 'rtr1', 32767, '/interfaces/', 'sensor1', 'tag1' '5000', oc)
        end
    end

    sub_test_case 'Authentication' do
        test 'Password based' do
            d = create_driver(%Q(
                server ["127.0.0.1"]
                sensors ["aaa"]
                username "user123"
                password "pass123"
            ))
            oc = Fluent::OCInput.new
            
            ENV['MOCHA_COUNT'] = '1'
            res = mock()
            res.stubs(:system_id).returns('')
            res.stubs(:component_id).returns('component_id')
            res.stubs(:sub_component_id).returns('sub_component_id')
            res.stubs(:path).returns('path')
            res.stubs(:sequence_number).returns('sequence_number')
            res.stubs(:timestamp).returns('timestamp')
            json = {"key"=>"__timestamp__", "strValue"=>"1497431542576"}
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
            
            login_resp = mock()
            login_resp.stubs(:result).returns('True')
            login_check = mock()
            login_check.stubs(:login_check).returns(login_resp)

            GRPC::Core::Channel.stubs(:new).returns('')
            Authentication::Login::Stub.stubs(:new).returns(login_check)
            Authentication::LoginRequest.stubs(:new).returns('')

            Telemetry::OpenConfigTelemetry::Stub.stubs(:new).returns('Test')
            stub, err = Telemetry::OpenConfigTelemetry::Stub.new('127.0.0.1:32767', :this_channel_is_insecure)
            Telemetry::OpenConfigTelemetry::Stub.any_instance.stubs(:telemetry_subscribe).returns(resp)
            d.run
            #assert_equal "", oc.start_collection(stub, 'rtr1', 32767, '/interfaces/', 'sensor1', 'tag1' '5000', oc)
        end
        test 'SSL based' do
            d = create_driver(%Q(
                server ["127.0.0.1"]
                sensors ["aaa"]
                certFile '/tmp/1'
            ))
            oc = Fluent::OCInput.new
            
            ENV['MOCHA_COUNT'] = '1'
            res = mock()
            res.stubs(:system_id).returns('')
            res.stubs(:component_id).returns('component_id')
            res.stubs(:sub_component_id).returns('sub_component_id')
            res.stubs(:path).returns('path')
            res.stubs(:sequence_number).returns('sequence_number')
            res.stubs(:timestamp).returns('timestamp')
            json = {"key"=>"__timestamp__", "strValue"=>"1497431542576"}
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
            
            GRPC::Core::ChannelCredentials.stubs(:new).returns('cert')
            File.stubs(:read).returns('Cert')
            Telemetry::OpenConfigTelemetry::Stub.stubs(:new).returns('Test')
            stub, err = Telemetry::OpenConfigTelemetry::Stub.new('127.0.0.1:32767', :this_channel_is_insecure)
            Telemetry::OpenConfigTelemetry::Stub.any_instance.stubs(:telemetry_subscribe).returns(resp)
            d.run
            #assert_equal "", oc.start_collection(stub, 'rtr1', 32767, '/interfaces/', 'sensor1', 'tag1' '5000', oc)
        end
    end
end
