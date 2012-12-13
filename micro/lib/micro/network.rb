require 'netaddr'
require 'socket'
require 'resolv'
require 'timeout'
require 'fileutils'
require 'tempfile'

module VCAP
  module Micro
    class Network
      attr_accessor :type

      A_ROOT_SERVER = '198.41.0.4'
      OFFLINE_FILE = "/var/vcap/micro/offline"
      OFFLINE_CONF = "/etc/dnsmasq.d/offline.conf"
      OFFLINE_TEMPLATE = "/var/vcap/micro/config/offline.conf"
      DNSMASQ_UPSTREAM = '/etc/dnsmasq.d/server'

      def self.local_ip(route = A_ROOT_SERVER)
        retries ||= 0
        route ||= A_ROOT_SERVER
        orig, Socket.do_not_reverse_lookup = Socket.do_not_reverse_lookup, true
        UDPSocket.open {|s| s.connect(route, 1); s.addr.last }
      rescue Errno::ENETUNREACH
        # happens on boot when dhcp hasn't completed when we get here
        sleep 3
        retries += 1
        retry if retries < 3
      ensure
        Socket.do_not_reverse_lookup = orig
      end

      def self.gateway
        %x{netstat -rn 2>&1}.split("\n").each do |line|
          fields = line.split(/\s+/)
          if fields[0] =~ /^default|0\.0\.0\.0$/
            return fields[1]
          end
        end
        nil
      end

      def self.ping(host, count=3)
        %x{ping -c #{count} #{host} > /dev/null 2>&1}
        $? == 0
      end

      # create a class variable?
      def self.ext_lookup(name)
        Network.resolv_guard(name) do
          Resolv::DNS.open(:nameserver => ['208.78.70.9']) do |dns|
            dns.getaddress(name)
          end
        end
      end

      # use Resolve.new to force the lookup to use the current resolv.conf
      def self.lookup(name)
        Network.resolv_guard(name) do
          Resolv.new.getaddress(name)
        end
      end

      # use Resolve.new to force the lookup to use the current resolv.conf
      def self.reverse_lookup(ip)
        Network.resolv_guard(ip) do
          Resolv.new.getname(ip)
        end
      end

      def self.resolv_guard(query)
        yield
      rescue Errno::ENETUNREACH => e
        Console.logger.error("network unreachable for #{query}: #{e.message}")
        nil
      rescue Resolv::ResolvError => e
        Console.logger.error("failed to resolve #{query}: #{e.message}")
        nil
      end

      def sh(cmd)
        result = %x{#{cmd}}
        yield result if block_given? && $? != 0
      end

      def initialize
        @logger = Console.logger
        @state = Statemachine.build do
          state :unconfigured do
            event :start, :starting
            event :fail, :failed
          end
          state :starting do
            event :timeout, :failed
            event :fail, :failed
            event :started, :up
            event :restart, :starting
          end
          state :failed do
            event :restart, :starting
          end
          state :up do
            event :connection_lost, :offline
            event :restart, :starting
          end
          state :offline do
            event :recovered, :up
            event :restart, :starting
          end
        end
        @previous = nil

        if dhcp?
          @type = :dhcp
        else
          @type = :static
        end
        @state.start
        # assume that the network is up and running on start
        @state.started
      end

      def up?
        @state.state == :up
      end

      def starting?
        @state.state == :starting
      end

      def failed?
        @state.state == :failed
      end

      def offline?
        @state.state == :offline
      end

      def status
        @state.state
      end

      def online?
        !File.exist?(OFFLINE_FILE)
      end

      def online_status
        online? ? "online" : "offline"
      end

      # use a file as a flag so offline mode can be toggled externally through vmrun
      def toggle_online_status
        online? ? offline! : online!
      end

      def online!
        FileUtils.rm_f(OFFLINE_FILE)
        FileUtils.rm_f(OFFLINE_CONF)

        # Uncomment upstream DNS servers in /etc/dnsmasq.d/server
        if File.exist?(DNSMASQ_UPSTREAM)
          temp = Tempfile.new('server')
          open(DNSMASQ_UPSTREAM).each_line do |line|
            temp.write(line.sub(/^# /, ''))
          end
          temp.flush
          FileUtils.mv temp.path, DNSMASQ_UPSTREAM
        end

        restart_dnsmasq
      end

      def offline!
        FileUtils.touch(OFFLINE_FILE)
        FileUtils.cp(OFFLINE_TEMPLATE, OFFLINE_CONF)

        # Comment out upstream DNS servers in /etc/dnsmasq.d/server
        # to prevent DNS loops.
        if File.exist?(DNSMASQ_UPSTREAM)
          temp = Tempfile.new('server')
          open(DNSMASQ_UPSTREAM).each_line do |line|
            if line[/^# /]
              new_line = line
            else
              new_line = "# #{line}"
            end
            temp.write new_line
          end
          temp.flush
          FileUtils.mv temp.path, DNSMASQ_UPSTREAM
        end

        restart_dnsmasq
      end

      def restart_dnsmasq
        # restart command doesn't always work, start and stop seems to be more reliable
        %x{/etc/init.d/dnsmasq stop}
        %x{/etc/init.d/dnsmasq start}
      end

      def connection_lost
        $stderr.puts "\nnetwork connectivity lost :-("
        @state.connection_lost
        @previous = @state.state
      end

      # async
      def restart
        @state.restart
        Thread.new do
          restart_with_timeout
        end
      end

      def restart_with_timeout
        Timeout::timeout(10) do
          sh 'service network-interface stop INTERFACE=eth0 2>&1'
          # ignoring failures on stop
          sh 'service network-interface start INTERFACE=eth0 2>&1' do
            @state.timeout
          end
        end
        # TODO this should only be displayed when it can resolve DNS queries again
        $stderr.puts "network connectivity regained :-)" if @previous == :offline
        @state.started
      rescue Timeout::Error
        @state.timeout
      ensure
        @previous = @state.state
      end

      INTERFACES = "/etc/network/interfaces"
      def dhcp?
        if File.exist?(INTERFACES)
          File.open(INTERFACES) do |f|
            f.readlines.each do |line|
              return true if line.match(/^iface eth0 inet dhcp$/)
            end
          end
        end
        false
      end

      def dhcp
        previous = @type
        @type = :dhcp
        write_network_interfaces(BASE_TEMPLATE + DHCP_TEMPLATE, nil)
        # no need to restart if we already are running dhcp
        restart unless @type == previous
      end

      def static(net)
        @type = :static
        @state.restart
        cidr_ip_mask = "#{net['address']} #{net['netmask']}"

        net_cidr = NetAddr::CIDR.create(cidr_ip_mask)
        net['network'] = net_cidr.network
        net['broadcast'] = net_cidr.broadcast

        write_network_interfaces(BASE_TEMPLATE + MANUAL_TEMPLATE, net)

        if net['dns']
          dns(net['dns'])
        end
        restart
      rescue NetAddr::ValidationError => e
        puts("invalid network: #{cidr_ip_mask}")
        @state.fail
      end

      RESOLV_CONF = "/etc/resolv.conf"
      # Comma separated list of dns servers
      def dns(dns_string)
        servers = dns_string.split(/,/).map { |s| s.gsub(/\s+/, '') }
        open('/etc/dnsmasq.d/server', 'w') do |f|
          servers.each do |s|
            f.puts "#{offline? ? '# ' : ''}server=#{s}"
          end
        end
        restart_dnsmasq

        File.open(RESOLV_CONF, 'w') do |f|
          f.puts("nameserver 127.0.0.1")
        end
      end

      def write_network_interfaces(template_data, net)
        FileUtils.mkdir_p(File.dirname(INTERFACES))

        template = ERB.new(template_data, 0, '%<>')
        result = template.result(binding)
        File.open(INTERFACES, 'w') do |fh|
          fh.write(result)
        end
      end

      BASE_TEMPLATE =<<TEMPLATE
auto lo
iface lo inet loopback

TEMPLATE

      DHCP_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet dhcp
TEMPLATE

      MANUAL_TEMPLATE = <<TEMPLATE
auto eth0
iface eth0 inet static
address <%= net["address"]%>
network <%= net["network"] %>
netmask <%= net["netmask"]%>
broadcast <%= net["broadcast"] %>
gateway <%= net["gateway"] %>
TEMPLATE

    end
  end
end
