$:.push("#{File.dirname(__FILE__)}/..")

require 'PortScan'

# Ports:
#        135  - Microsoft Remote Procedure Call (RPC)
#        139  - NetBIOS Session (TCP), Windows File and Printer Sharing
#        445  - SMB (Server Message Block) over TCP/IP
#        3389 - RDP

class WindowsProbe
	def self.probe(ost)
	  $log.debug "WindowsProbe: probing ip = #{ost.ipaddr}" if $log
		ost.os << :mswin  if PortScanner.scanPortArray(ost, [135, 139]).length == 2
		$log.debug "WindowsProbe: probe of ip = #{ost.ipaddr} complete" if $log
	end
end
