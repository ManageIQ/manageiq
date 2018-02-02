#!/usr/bin/env ruby

# usage: ruby miqldap_to_sssd -h
#
# upgrades authentication mode from LDAP(s) to External Auth with SSSD
# Alternatively, it will update all user records to have a userid in UPN format

$LOAD_PATH.push(File.expand_path(__dir__))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(miqldap_to_sssd))))

require File.expand_path('../config/environment', __dir__)

require 'authconfig'
require 'cli'
require 'configure_apache'
require 'configure_appliance_settings'
require 'configure_database'
require 'configure_selinux'
require 'configure_sssd_rules'
require 'miqldap_configuration'
require 'converter'
require 'services'
require 'sssd_conf'

module MiqLdapToSssd
  LOGGER = Logger.new('log/miqldap_to_sssd.log')

  LOGGER.formatter = proc do |severity, time, _progname, msg|
    "[#{time}] #{severity}: #{msg}\n"
  end

  MiqLdapToSssd::Cli.run(ARGV) if __FILE__ == $PROGRAM_NAME
end
