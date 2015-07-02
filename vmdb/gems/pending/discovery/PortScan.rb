require 'timeout'
require 'socket'

class PortScanner
	def self.scanPortArray(ost, ports)
		portsFound = []
		ports.each {|p| portsFound << p if portOpen(ost, p)}
		return portsFound
	end
	
	def self.scanPortRange(ost, startPort, endPort)
		portsFound = []
		startPort.upto(endPort) {|p| portsFound << p if portOpen(ost, p)}
		return portsFound
	end

	def self.portAndOrScan?(ost, ports)
		ports.each { |p| return false unless portOrScan?(ost, p) }
		return true
	end

	def self.portOrScan?(ost, ports)
		ports = [ ports ] unless ports.kind_of?(Array)
		ports.each { |p| return true if portOpen(ost, p) }
		return false
	end
	
	def self.portOpen(ost, port)
		ost.timeout ||= 10
		begin
			Timeout::timeout(ost.timeout) do
				s = TCPSocket.open(ost.ipaddr, port)
				s.close
				$log.debug "PortScan: ip = #{ost.ipaddr}, port = #{port}, Found port" if $log
				true
			end
		rescue Timeout::Error, StandardError => err
			$log.debug "PortScan: ip = #{ost.ipaddr}, port = #{port}, #{err}" if $log
			false
		end
	end
end
