# Generated by the protocol buffer compiler.  DO NOT EDIT!
# Source: oc.proto for package 'telemetry'
# Original file comments:
#
# Copyrights (c) 2016, Juniper Networks, Inc.
# All rights reserved.
#
#
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#
#
# Nitin Kumar          04/07/2016
# Abbas Sakarwala      04/07/2016
#
# This file defines the Openconfig Telemetry RPC APIs (for gRPC).
#
# https://github.com/openconfig/public/blob/master/release/models/rpc/openconfig-rpc-api.yang
#
# Version 1.0
#
#

require 'grpc'
require 'oc_pb'

module Telemetry
  module OpenConfigTelemetry
    # Interface exported by Agent
    class Service

      include GRPC::GenericService

      self.marshal_class_method = :encode
      self.unmarshal_class_method = :decode
      self.service_name = 'telemetry.OpenConfigTelemetry'

      # Request an inline subscription for data at the specified path.
      # The device should send telemetry data back on the same
      # connection as the subscription request.
      rpc :telemetrySubscribe, SubscriptionRequest, stream(OpenConfigData)
      # Terminates and removes an exisiting telemetry subscription
      rpc :cancelTelemetrySubscription, CancelSubscriptionRequest, CancelSubscriptionReply
      # Get the list of current telemetry subscriptions from the
      # target. This command returns a list of existing subscriptions
      # not including those that are established via configuration.
      rpc :getTelemetrySubscriptions, GetSubscriptionsRequest, GetSubscriptionsReply
      # Get Telemetry Agent Operational States
      rpc :getTelemetryOperationalState, GetOperationalStateRequest, GetOperationalStateReply
      # Return the set of data encodings supported by the device for
      # telemetry data
      rpc :getDataEncodings, DataEncodingRequest, DataEncodingReply
    end

    Stub = Service.rpc_stub_class
  end
end
