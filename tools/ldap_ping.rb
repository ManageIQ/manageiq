#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

LOG_DIR = "./"
logfile = File.join(LOG_DIR, "ldap_ping.log")
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
    false
  end
end

ldap_hosts   = ::Settings.authentication.ldaphost
username     = ::Settings.authentication.bind_dn
password     = ::Settings.authentication.bind_pwd
bind_timeout = ::Settings.authentication.bind_timeout.to_i_with_method
if ldap_hosts.to_s.strip.empty?
  log(:info, "LDAP Host cannot be blank")
  exit
end

ldap_addresses = []
Array.wrap(ldap_hosts).each do |host|
  _canonical, _aliases, _type, *addresses = TCPSocket.gethostbyname(host)
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
    Timeout.timeout(bind_timeout) do
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
