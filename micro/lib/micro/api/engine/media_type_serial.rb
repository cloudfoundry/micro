module VCAP

  module Micro

    module Api

      module Engine

        module Rack

          # Rack middleware for automatic JSON parsing of inbound data based on
          # the content type.
          #
          # Also automatically sets the content type for outbound data.
          class MediaTypeSerial

            def initialize(app)
              @app = app
            end

            def call(env)
              request = ::Rack::Request.new(env)

              media_type = MediaType.from_content_type(request.content_type)

              if media_type
                # Wrap the JSON to conform to what the json gem expects for
                # json_create.
                new_json = {
                  :json_class => media_type.name,
                  :data => JSON.parse(request.body.read)
                }.to_json

                env['media_type_object'] = JSON.parse(new_json, :create_additions => true)
              end

              status, headers, response = @app.call(env)

              if response.respond_to?(:media_type)
                # For now,  serve as application/json to view in the browser for easy debugging.
                # headers['Content-Type'] = response.media_type
                headers['Content-Type'] = 'application/json'
              end

              [status, headers, response]
            end

          end

        end

      end

    end

  end

end
