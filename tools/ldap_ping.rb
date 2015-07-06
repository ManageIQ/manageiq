LOG_DIR = "./"
logfile = File.join(LOG_DIR, "ldap_ping.log")
#File.delete(logfile) if File.exist?(logfile)
$log = VMDBLogger.new(logfile)
$log.level = VMDBLogger.const_get("INFO")

def log(level, msg)
  log_prefix = "LdapPing:"
  puts "[#{Time.now.utc}] #{level.to_s.upcase}: #{msg}"
  $log.send(level, "#{log_prefix} #{msg}")
end

#################################
log(:info, "==================================")
log(:info, "Starting")

unless MiqLdap.using_ldap?
  log(:info, "Not Configured to use LDAP")
  exit
end

class MiqLdap
  def self.resolve_ldap_host?
    return false
  end
end

authentication = VMDB::Config.new("vmdb").config[:authentication]

if authentication.nil?
  log(:info, "Authentication Section Not Configured")
  exit
end

ldap_hosts   = authentication[:ldaphost]
username     = authentication[:bind_dn]
password     = authentication[:bind_pwd]
bind_timeout = authentication[:bind_timeout] || MiqLdap.default_bind_timeout
if ldap_hosts.to_s.strip.empty?
  log(:info, "LDAP Host cannot be blank")
  exit
end

ldap_addresses = []
ldap_hosts.to_miq_a.each do |host|
  canonical, aliases, type, *addresses = TCPSocket.gethostbyname(host)
  log(:info, "Resolved host <#{host}> has these IP Address: #{addresses.inspect}")
  ldap_addresses += addresses
end

ldap_addresses.each do |address|
  begin
    log(:info, "----------------------------------")
    log(:info, "Binding to LDAP: Host: <#{address}>, User: <#{username}>...")
    ldap     = MiqLdap.new(:host => address)
    raw_ldap = ldap.ldap
    raw_ldap.authenticate(username, password)
    Timeout::timeout(bind_timeout) do
      if raw_ldap.bind
        log(:info, "Binding to LDAP: Host: <#{address}>, User: <#{username}>... successful")
      else
        log(:warn, "Binding to LDAP: Host: <#{address}>, User: <#{username}>... unsuccessful because <#{raw_ldap.get_operation_result.message}>")
      end
    end
  rescue Exception => err
    log(:warn, "Binding to LDAP: Host: <#{address}>, User: <#{username}>... failed because <#{err.message}>")
  end
end

log(:info, "Done")

exit 0
