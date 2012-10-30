module VCAP

  module Micro

    module Api

      module MediaType

        class NetworkInterface < Engine::MediaType
          MediaType = 'application/vnd.vmware.mcf-network-interface+json'

          Links = {
            :self => [:get, self],
            :microcloud => [:get, MicroCloud],
            :edit => [:post, self],
          }

          def initialize(fields={})
            super fields

            @name = fields[:name]
            @ip_address = fields[:ip_address]
            @netmask = fields[:netmask]
            @gateway = fields[:gateway]
            @nameservers = fields[:nameservers]
            @is_dhcp = fields[:is_dhcp]
          end

          attr_accessor :name
          attr_accessor :ip_address
          attr_accessor :netmask
          attr_accessor :gateway
          attr_accessor :nameservers
          attr_accessor :is_dhcp
          attr_accessor :is_up
        end

      end

    end

  end

end
