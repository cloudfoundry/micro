module VCAP

  module Micro

    module Api

      module Route

        # Routes for domain name.
        module DomainName

          def self.registered(app)

            app.get '/domain_name' do
              config_file = ConfigFile.new

              domain_name = MediaType::DomainName.new(
                :name => config_file.subdomain,
                :token => config_file.token,
                :synched => config_file.ip == Micro.local_ip,
              )

              domain_name.link(:self, request.url)
              domain_name.link(:microcloud, url('/'))
            end

            app.post '/domain_name' do
              expect MediaType::DomainName

              domain_name = env['media_type_object']

              if domain_name.token or domain_name.name
                config_file = ConfigFile.new
                spec = ApplySpec.new.read
                http_proxy = spec.http_proxy

                ip = Micro.local_ip

                if domain_name.token
                  InternetConnection.new.set_connected

                  dns_api_client = DnsApiClient.new(
                    :root_url => "https://#{config_file.api_host}/api/v1/micro",
                    :http_proxy => http_proxy)

                  dns_info = dns_api_client.redeem_nonce(domain_name.token)

                  dns_api_client.update_dns(ip, dns_info)

                  config_file.write do |c|
                    c.name = dns_info['name']
                    c.cloud = dns_info['cloud']
                    c.admin_email = dns_info['email']
                    c.token = dns_info['auth-token']
                    c.ip = ip
                  end

                  new_domain_name = config_file.subdomain
                else
                  config_file.write do |c|
                    c.name, c.cloud = domain_name.name.split('.', 2)
                    c.ip = ip
                  end

                  InternetConnection.new.set_disconnected

                  new_domain_name = domain_name.name
                end

                dnsmasq = Dnsmasq.new.read
                dnsmasq.domain = new_domain_name
                dnsmasq.ip = ip
                dnsmasq.write

                spec = ApplySpec.new.read

                spec.write do |as|
                  as.domain = config_file.subdomain
                end

                settings.bosh.apply_spec(spec.spec)
              elsif domain_name.synched
                config_file = ConfigFile.new

                config_file.write do |c|
                    c.ip = Micro.local_ip
                end

                if config_file.token
                  dns_api_client = DnsApiClient.new(
                    :root_url => "https://#{config_file.api_host}/api/v1/micro",
                    :http_proxy => http_proxy)

                  dns_api_client.update_dns(config_file.ip,
                    'cloud' => config_file.cloud,
                    'name' => config_file.name,
                    'auth-token' => config_file.token)
                end
              end
            end

          end

        end

      end

    end

  end

end
