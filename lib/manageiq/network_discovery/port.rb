require 'timeout'
require 'socket'

module ManageIQ
  module NetworkDiscovery
    class Port
      def self.all_open?(ost, ports)
        ports.all? { |port| open?(ost, port) }
      end

      def self.any_open?(ost, ports)
        Array(ports).any? { |port| open?(ost, port) }
      end

      def self.open?(ost, port)
        ost.timeout ||= 10
        begin
          Timeout.timeout(ost.timeout) do
            TCPSocket.open(ost.ipaddr, port).close
            $log&.debug("Port open: IP = #{ost.ipaddr}, port = #{port}")
            true
          end
        rescue Timeout::Error => err
          $log&.debug("Port scan timeout: ip = #{ost.ipaddr}, port = #{port}, #{err}")
          false
        rescue StandardError => err
          $log&.debug("Port scan error: ip = #{ost.ipaddr}, port = #{port}, #{err}")
          false
        end
      end

      def self.scan_open(ost, ports)
        Array(ports).select { |port| open?(ost, port) }
      end
    end
  end
end
