require 'erb'
require 'yaml'

module VCAP

  module Micro

    # Aggregate job statuses into group status.
    class ServiceStatus

      def initialize(options={})
        @groups_path =
          options[:groups_path] || '/var/vcap/jobs/micro/config/monit.yml'

        @monitrc_template = ERB.new(
          options[:monitrc_template] ||
          '/var/vcap/monit/job/micro.micro_<%=name%>.monitrc')

        @job_groups = nil
      end

      def read
        @job_groups = YAML.load_file(@groups_path)
        self
      end

      def group_enabled?(name)
        File.exist?(@monitrc_template.result(binding))
      end

      # Return the status of job groups in this form:
      #
      # { group => { :enabled => true, :health => :ok } }
      def status(bosh_agent_status)
        result = {}

        @job_groups.each do |group_name, jobs|
          group_enabled = group_enabled?(group_name)

          result[group_name] = {
            :enabled => group_enabled
          }

          if group_enabled
            all_running = jobs.all? {
              |name| bosh_agent_status[name][:status][:message] ==
              'running' }
            result[group_name][:health] = all_running ? :ok : :failed
          end
        end

        result
      end

      attr_reader :job_groups
    end

  end

end
