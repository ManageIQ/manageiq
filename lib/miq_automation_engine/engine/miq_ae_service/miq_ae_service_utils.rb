require 'discovery/port_scanner'

# Automate Method Utility Class
class MiqAeServiceUtils
  include Vmdb::Logging
  include DRbUndumped

  # Check if a port is open on given ip address
  # returns true if the port is open
  # returns false if the ip address is not reachable
  #                      or the port is not open
  #
  # ==== Attributes
  #
  # * +ipaddr+ - The ip address of the server
  # * +port+ - The port number
  # * +timeout+ - optional How long to wait to check for connection,
  #               default is 10 seconds
  #
  # ==== Examples
  #
  # Check if the SSH port is open on the server with ip address of 1.1.1.94
  #     utils = $evm.utils
  #     utils.port_open('1.1.1.94', 22)
  #
  def port_open(ipaddr, port, timeout = 10)
    PortScanner.portOpen(OpenStruct.new(:ipaddr => ipaddr, :timeout => timeout),
                         port)
  end
end
