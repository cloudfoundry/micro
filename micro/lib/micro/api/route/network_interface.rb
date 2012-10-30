 module VCAP

  module Micro

    module Api

      module Route

        # Routes for the network interface.
        module NetworkInterface

          def self.registered(app)

            app.get '/network_interface' do
              interface = Micro::NetworkInterface.new('eth0')

              network_interface = MediaType::NetworkInterface.new(
                :name => interface.name,
                :ip_address => interface.ip,
                :netmask => interface.netmask,
                :gateway => interface.gateway,
                :nameservers => 'nameservers',
                :is_dhcp => nil,
              )

              network_interface.link(:self, request.url)
              network_interface.link(:microcloud, url('/'))
              network_interface.link(:edit, request.url)
            end

          end

        end

      end

    end

  end

end
