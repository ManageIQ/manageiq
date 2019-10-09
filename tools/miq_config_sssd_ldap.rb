#!/usr/bin/env ruby

# usage: ruby miq_config_sssd_ldap -h
#
# upgrades authentication mode from LDAP(s) to External Auth with SSSD
# Alternatively, it will update all user records to have a userid in UPN format

$LOAD_PATH.push(File.expand_path(__dir__))
$LOAD_PATH.push(File.expand_path(File.join(__dir__, %w[miq_config_sssd_ldap])))

require File.expand_path('../config/environment', __dir__)

require 'auth_establish'
require 'cli_config'
require 'cli_convert'
require 'configure_apache'
require 'configure_appliance_settings'
require 'configure_database'
require 'configure_selinux'
require 'configure_sssd_rules'
require 'miqldap_configuration'
require 'converter'
require 'services'
require 'sssd_conf'

module MiqConfigSssdLdap
  LOGGER = Logger.new('log/miq_config_sssd_ldap.log')

  LOGGER.formatter = proc do |severity, time, _progname, msg|
    "[#{time}] #{severity}: #{msg}\n"
  end

  if $PROGRAM_NAME == __FILE__
    action = ARGV.shift

    case action
    when "convert"
      MiqConfigSssdLdap::CliConvert.run(ARGV)
    when "config"
      MiqConfigSssdLdap::CliConfig.run(ARGV)
    else
      raise ArgumentError, "The first argument must be \"convert\" or \"config\""
    end
  end
end
