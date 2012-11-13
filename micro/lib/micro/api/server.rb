require 'sinatra/base'

module VCAP

  module Micro

    module Api

      # Base for Sinatra app.
      #
      # Automatically loads all routes in the Route module.
      class Server < Sinatra::Base
        helpers Engine::ExpectHelper

        set :bosh, Micro::BoshWrapper.new

        Route.constants.each do |c|
          o = Route.const_get(c)
          register o  if o.is_a?(Module)
        end

      end

    end

  end

end
