# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-grpc-oc-keyvalue"
  spec.version       = "0.0.1"
  spec.authors       = ["Vijay Kumar Gadde"]
  spec.email         = ["vijaygadde@juniper.net"]
  spec.summary       = %q{fluentd input plugin for OpenConfig Key Value Pair over gRPC}
  spec.description   = %q{fluentd input plugin for OpenConfig Key Value Pair over gRPC}
  spec.homepage      = "http://github.com/?????"
  spec.license       = "MIT"

  #spec.files         = `git ls-files`.split($/)
  spec.files         = ["lib/fluent/plugin/in_juniper_openconfig.rb", "lib/oc_pb.rb", "lib/oc_services_pb.rb"]
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "grpc", "~> 1.3.4"
  spec.add_runtime_dependency "grpc-tools", "~> 1.3.4"
  spec.add_runtime_dependency "fluentd"
  spec.add_runtime_dependency "yajl-ruby"
  spec.add_runtime_dependency "test-unit"
  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "mocha"
end
