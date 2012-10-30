module VCAP

  module Micro

    module Api

      module Route

        # Routes for individual service status.
        module Service

          def self.registered(app)

            app.get '/service/:name' do |name|
              service_status = ServiceStatus.new.read

              group_status = service_status.status(settings.bosh.status)[name]

              service = MediaType::Service.new(
                :name => name,
                :enabled => group_status[:enabled],
                :health => group_status[:health]
                )

              service.link(:self, url("/service/#{name}"))
              service.link(:edit, url("/service/#{name}"))
              service.link(:services, url("/services"))
            end

          end

        end

      end

    end

  end

end
