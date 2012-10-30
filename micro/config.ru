$:.unshift(File.join(File.dirname(__FILE__), 'lib'))

# TODO: remove this
$:.unshift '/var/vcap/bosh/agent/lib'

require 'micro'

use VCAP::Micro::Api::Engine::Rack::MediaTypeSerial

run VCAP::Micro::Api::Server
