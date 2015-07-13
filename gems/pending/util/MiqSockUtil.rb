require 'socket'

class MiqSockUtil
    
    def self.getHostName
        Socket.gethostname
    end

    # Return the cannonical name for host in DNS
    def self.getFullyQualifiedDomainName
      Socket.gethostbyname( Socket.gethostname ).first
    end
    
    def self.getIpAddr
        # Skip 127.0.x.x addresses on first pass
        x = Socket.getaddrinfo(Socket.gethostname, Socket::AF_INET).detect {| af, port, name, addr | af == "AF_INET" && addr !~ /^127\.0/}
        x = Socket.getaddrinfo(Socket.gethostname, Socket::AF_INET).detect {| af, port, name, addr | af == "AF_INET"} if x.nil?
        return x[3] unless x.nil?
        return nil
    end

    def self.resolve_hostname(hostname)
      # Remove the domain suffix if it is included in the hostname      
      TCPSocket.gethostbyname(hostname.split(',').first).last
    end

    def self.hostname_from_ip(ip_address)
      return Socket.getaddrinfo(ip_address, nil)[0][2]
    end

end # class MiqSockUtil

if __FILE__ == $0
  require 'benchmark'
  time = Benchmark.realtime do
    puts "MiqSockUtil.getFullyQualifiedDomainName: #{MiqSockUtil.getFullyQualifiedDomainName}"
    puts "MiqSockUtil.getHostName                : #{MiqSockUtil.getHostName}"
    puts "MiqSockUtil.getIpAddr                  : #{MiqSockUtil.getIpAddr}"
    puts "MiqSockUtil.resolve_hostname('luke') : #{MiqSockUtil.resolve_hostname('luke')}"
    puts "MiqSockUtil.resolve_hostname('yoda.manageiq.com') : #{MiqSockUtil.resolve_hostname('yoda.manageiq.com')}"
    puts "MiqSockUtil.hostname_from_ip('192.168.252.137') : #{MiqSockUtil.hostname_from_ip('192.168.252.137')}"
  end
  puts "Completed in [#{time}] seconds"
end
