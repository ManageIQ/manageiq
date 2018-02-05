require 'timeout'
require 'socket'

module ManageIQ
  module Network
    class Port
      def self.all_open?(ost, ports)
        ports.each { |port| return false unless any_open?(ost, port) }
        true
      endf

      def self.any_open?(ost, ports)
        ports = [ports] unless ports.kind_of?(Array)
        ports.each { |port| return true if open?(ost, port) }
        false
      end

      def self.open?(ost, port)
        ost.timeout ||= 10
        begin
          Timeout.timeout(ost.timeout) do
            s = TCPSocket.open(ost.ipaddr, port)
            s.close
            $log.debug("Port: IP = #{ost.ipaddr}, port = #{port}, Open") if $log
            true
          end
        rescue Timeout::Error => err
          $log.debug("Port scan timeout: ip = #{ost.ipaddr}, port = #{port}, #{err}") if $log
          false
        rescue StandardError => err
          $log.debug("Port scan error: ip = #{ost.ipaddr}, port = #{port}, #{err}") if $log
          false
        end
      end

      def self.scan_array(ost, ports)
        ports_found = []
        ports.each { |port| ports_found << port if open?(ost, port) }
        ports_found
      end

      def self.scan_range(ost, start_port, end_port)
        ports_found = []
        start_port.upto(end_port) { |port| ports_found << port if open?(ost, port) }
        ports_found
      end
    end
  end
end
