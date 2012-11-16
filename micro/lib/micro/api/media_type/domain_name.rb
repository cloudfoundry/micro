module VCAP

  module Micro

    module Api

      module MediaType

        class DomainName < Engine::MediaType
          MediaType = 'application/vnd.vmware.mcf-domain-name+json'

          Links = {
            :self => [:get, self],
            :microcloud => [:get, MicroCloud],
            :edit => [:post, self],
          }

          def initialize(fields={})
            super fields

            @name = fields[:name]
            @token = fields[:token]
            @synched = fields[:synched]
          end

          attr_accessor :name
          attr_accessor :token
          attr_accessor :synched
        end

      end

    end

  end

end
