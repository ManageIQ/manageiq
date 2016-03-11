#!/usr/bin/env ruby
# description: ManageIQ appliance console
#

# Simulate rubygems adding the top level appliance_console.rb's directory to the path.
$LOAD_PATH.push(File.dirname(__FILE__))

require 'pathname'

RAILS_ROOT = [
  Pathname.new("/var/www/miq/vmdb"),
  Pathname.new(File.expand_path(File.join(__dir__, "../..")))
].detect { |f| File.exist?(f) }

# Set up Environment
ENV['BUNDLE_GEMFILE'] ||= RAILS_ROOT.join("Gemfile").to_s
require 'bundler'
Bundler.setup

require 'fileutils'
require 'highline/import'
require 'highline/system_extensions'
require 'rubygems'
require 'bcrypt'
require 'linux_admin'
require 'util/vmdb-logger'
require 'awesome_spawn'
include HighLine::SystemExtensions

require 'i18n'
LOCALES = File.join(File.expand_path(File.dirname(__FILE__)), "appliance_console/locales/*.yml")
I18n.load_path = Dir[LOCALES].sort
I18n.enforce_available_locales = true
I18n.backend.load_translations

$terminal.wrap_at = 80
$terminal.page_at = 25

require 'appliance_console/errors'

[:INT, :TERM, :ABRT, :TSTP].each { |s| trap(s) { raise MiqSignalError } }

VERSION_FILE  = RAILS_ROOT.join("VERSION")
LOGFILE       = RAILS_ROOT.join("log", "appliance_console.log")
DB_RESTORE_FILE = "/tmp/evm_db.backup".freeze

AS_OPTIONS = I18n.t("advanced_settings.menu_order").collect do |item|
  I18n.t("advanced_settings.#{item}")
end

require 'util/miq-password'
MiqPassword.key_root = "#{RAILS_ROOT}/certs"

# Load appliance_console libraries
require 'appliance_console/utilities'
require 'appliance_console/logging'
require 'appliance_console/database_configuration'
require 'appliance_console/internal_database_configuration'
require 'appliance_console/external_database_configuration'
require 'appliance_console/external_httpd_authentication'
require 'appliance_console/temp_storage_configuration'
require 'appliance_console/key_configuration'
require 'appliance_console/scap'
require 'appliance_console/certificate_authority'
require 'appliance_console/timezone_configuration'
require 'appliance_console/date_time_configuration'

require 'appliance_console/prompts'
include ApplianceConsole::Prompts

# Restore database choices
RESTORE_LOCAL   = "Local file".freeze
RESTORE_NFS     = "Network File System (nfs)".freeze
RESTORE_SMB     = "Samba (smb)".freeze
RESTORE_OPTIONS = [RESTORE_LOCAL, RESTORE_NFS, RESTORE_SMB, ApplianceConsole::CANCEL].freeze

# Restart choices
RE_RESTART  = "Restart".freeze
RE_DELLOGS  = "Restart and Clean Logs".freeze
RE_OPTIONS  = [RE_RESTART, RE_DELLOGS, ApplianceConsole::CANCEL].freeze

NETWORK_INTERFACE = "eth0".freeze

module ApplianceConsole
  eth0 = LinuxAdmin::NetworkInterface.new(NETWORK_INTERFACE)
  ip = eth0.address
  # Because it takes a few seconds, get the database information once in the outside loop
  configured = ApplianceConsole::DatabaseConfiguration.configured?
  dbhost, database, region = ApplianceConsole::Utilities.db_host_database_region if configured

  clear_screen

  # Calling stty to provide the equivalent line settings when the console is run via an ssh session or
  # over the virtual machine console.
  system("stty -echoprt ixany iexten echoe echok")

  say("#{I18n.t("product.name")} Virtual Appliance\n")
  say("To administer this appliance, browse to https://#{ip}\n") if configured

  loop do
    begin
      dns = LinuxAdmin::Dns.new
      eth0.reload
      eth0.parse_conf

      host       = LinuxAdmin::Hosts.new.hostname
      ip         = eth0.address
      mac        = eth0.mac_address
      mask       = eth0.netmask
      gw         = eth0.gateway
      dns1, dns2 = dns.nameservers
      order      = dns.search_order.join(' ')
      timezone   = LinuxAdmin::TimeDate.system_timezone
      version    = File.read(VERSION_FILE).chomp if File.exist?(VERSION_FILE)
      configured = ApplianceConsole::DatabaseConfiguration.configured?

      summary_attributes = [
        "Hostname:", host,
        "IP Address:", ip,
        "Netmask:", mask,
        "Gateway:", gw,
        "Primary DNS:", dns1,
        "Secondary DNS:", dns2,
        "Search Order:", order,
        "MAC Address:", mac,
        "Timezone:", timezone,
        "Local Database:", ApplianceConsole::Utilities.pg_status,
        "#{I18n.t("product.name")} Database:", configured ? "postgres @ #{dbhost || "localhost"}" : "not configured",
        "Database/Region:", configured ? "#{database} / #{region || 0}" : "not configured",
        "External Auth:", ExternalHttpdAuthentication.config_status,
        "#{I18n.t("product.name")} Version:", version,
        "#{I18n.t("product.name")} Console:", configured ? "https://#{ip}" : "not configured"
      ]

      clear_screen

      say(<<-EOL)
Welcome to the #{I18n.t("product.name")} Virtual Appliance.

To modify the configuration, use a web browser to access the management page.

#{$terminal.list(summary_attributes, :columns_across, 2)}
        EOL

      press_any_key

      clear_screen
      selection = ask_with_menu("Advanced Setting", AS_OPTIONS, nil, true)
      case selection
      when I18n.t("advanced_settings.dhcp")
        say("DHCP Network Configuration\n\n")
        if agree("Apply DHCP network configuration? (Y/N): ")
          say("\nApplying DHCP network configuration...")

          resolv = LinuxAdmin::Dns.new
          resolv.search_order = []
          resolv.nameservers = []
          resolv.save

          eth0.enable_dhcp
          eth0.save

          say("\nAfter completing the appliance configuration, please restart #{I18n.t("product.name")} server processes.")
          press_any_key
        end

      when I18n.t("advanced_settings.static")
        say("Static Network Configuration\n\n")
        say("Enter the new static network configuration settings.\n\n")

        new_ip   = ask_for_ip("IP Address", ip)
        new_mask = ask_for_ip("Netmask", mask)
        new_gw   = ask_for_ip("Gateway", gw)
        new_dns1 = ask_for_ip("Primary DNS", dns1)
        new_dns2 = ask_for_ip_or_none("Secondary DNS (Enter 'none' for no value)")

        new_search_order = ask_for_many("domain", "Domain search order", order)

        clear_screen
        say(<<-EOL)
Static Network Configuration

        IP Address:      #{new_ip}
        Netmask:         #{new_mask}
        Gateway:         #{new_gw}
        Primary DNS:     #{new_dns1}
        Secondary DNS:   #{new_dns2}
        Search Order:    #{new_search_order.join(" ")}

          EOL

        if agree("Apply static network configuration? (Y/N)")
          say("\nApplying static network configuration...")

          resolv = LinuxAdmin::Dns.new
          resolv.search_order = []
          resolv.nameservers = []
          resolv.save

          begin
            network_configured = eth0.apply_static(new_ip, new_mask, new_gw, [new_dns1, new_dns2], new_search_order)
          rescue ArgumentError => e
            say("\nNetwork configuration failed: #{e.massage}")
            press_any_key
            next
          end

          unless network_configured
            say("\nNetwork interface failed to start using the values supplied.")
            press_any_key
            next
          end

          say("\nAfter completing the appliance configuration, please restart #{I18n.t("product.name")} server processes.")
          press_any_key
        end

      when I18n.t("advanced_settings.testnet")
        ApplianceConsole::Utilities.test_network

      when I18n.t("advanced_settings.hostname")
        say("Hostname Configuration\n\n")
        new_host = just_ask("new hostname", host)

        if new_host != host
          say("Applying new hostname...")
          system_hosts = LinuxAdmin::Hosts.new

          system_hosts.parsed_file.each { |line| line[:hosts].to_a.delete(host) } unless host =~ /^localhost.*/

          system_hosts.hostname = new_host
          system_hosts.set_canonical_hostname("127.0.0.1", new_host)
          system_hosts.save
          LinuxAdmin::Service.new("network").restart
          press_any_key
        end

      when I18n.t("advanced_settings.timezone")
        say("#{selection}\n\n")
        timezone_config = ApplianceConsole::TimezoneConfiguration.new(timezone)
        if timezone_config.ask_questions && timezone_config.activate
          say("Timezone configured")
          press_any_key
        else
          say("Timezone not configured")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.datetime")
        say("#{selection}\n\n")
        date_time_config = ApplianceConsole::DateTimeConfiguration.new
        if date_time_config.ask_questions && date_time_config.activate
          say("Date and time configured")
          press_any_key
        else
          say("Date and time not configured")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.httpdauth")
        say("#{selection}\n\n")

        httpd_auth = ExternalHttpdAuthentication.new(host)
        if httpd_auth.ask_questions && httpd_auth.activate
          httpd_auth.post_activation
          say("\nExternal Authentication configured successfully.\n")
          press_any_key
        else
          say("\nExternal Authentication configuration failed!\n")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.ca")
        say("#{selection}\n\n")
        begin
          ca = CertificateAuthority.new(:hostname => host)
          if ca.ask_questions && ca.activate
            say "\ncertificate result: #{ca.status_string}"
            unless ca.complete?
              say "After the certificates are retrieved, rerun to update service configuration files"
            end
            press_any_key
          else
            say("\nCertificates not fetched.\n")
            press_any_key
          end
        rescue AwesomeSpawn::CommandResultError => e
          say e.result.output
          say e.result.error
          say ""
          press_any_key
        end

      when I18n.t("advanced_settings.evmstop")
        say("#{selection}\n\n")
        service = LinuxAdmin::Service.new("evmserverd")
        if service.running?
          if ask_yn? "\nNote: It may take up to a few minutes for all #{I18n.t("product.name")} server processes to exit gracefully. Stop #{I18n.t("product.name")}"
            say("\nStopping #{I18n.t("product.name")} Server...")
            Logging.logger.info("EVM server stop initiated by appliance console.")
            service.stop
          end
        else
          say("\n#{I18n.t("product.name")} Server is not running...")
        end
        press_any_key

      when I18n.t("advanced_settings.evmstart")
        say("#{selection}\n\n")
        if ask_yn?("\nStart #{I18n.t("product.name")}")
          say("\nStarting #{I18n.t("product.name")} Server...")
          Logging.logger.info("EVM server start initiated by appliance console.")
          LinuxAdmin::Service.new("evmserverd").start
          press_any_key
        end

      when I18n.t("advanced_settings.dbrestore")
        say("#{selection}\n\n")
        ApplianceConsole::Utilities.bail_if_db_connections "preventing a database restore"

        task_params = []
        uri = nil

        # TODO: merge into 1 prompt
        case ask_with_menu("Restore Database File", RESTORE_OPTIONS, RESTORE_LOCAL, nil)
        when RESTORE_LOCAL
          validate = ->(a) { File.exist?(a) }
          uri = just_ask("location of the local restore file", DB_RESTORE_FILE, validate, "file that exists")
          task = "evm:db:restore:local"
          task_params = ["--", {:local_file => uri}]

        when RESTORE_NFS
          uri = ask_for_uri("location of the remote backup file\nExample: #{sample_url('nfs')})", "nfs")
          task = "evm:db:restore:remote"
          task_params = ["--", {:uri => uri}]

        when RESTORE_SMB
          uri = ask_for_uri("location of the remote backup file\nExample: #{sample_url('smb')}", "smb")
          user = just_ask("username with access to this file.\nExample: 'mydomain.com/user'")
          pass = ask_for_password("password for #{user}")

          task = "evm:db:restore:remote"
          task_params = ["--", {:uri => uri, :uri_username => user, :uri_password => pass}]

        when ApplianceConsole::CANCEL
          raise MiqSignalError
        end

        clear_screen
        say("#{selection}\n\n")

        delete_agreed = false
        if selection == RESTORE_LOCAL
          say "The local database restore file is located at: '#{uri}'.\n"
          delete_agreed = agree("Should this file be deleted after completing the restore? (Y/N): ")
        end

        say "\nNote: A database restore cannot be undone.  The restore will use the file: #{uri}.\n"
        if agree("Are you sure you would like to restore the database? (Y/N): ")
          say("\nRestoring the database...")
          rake_success = ApplianceConsole::Utilities.rake(task, task_params)
          if rake_success && delete_agreed
            say("\nRemoving the database restore file #{DB_RESTORE_FILE}...")
            File.delete(DB_RESTORE_FILE)
          elsif !rake_success
            say("\nDatabase restore failed")
          end
        end
        press_any_key

      when I18n.t("advanced_settings.dbregion_setup")
        say("#{selection}\n\n")
        unless configured
          say("There is no database configured yet, please choose #{I18n.t("advanced_settings.db_config")} instead.")
          press_any_key
          raise MiqSignalError
        end
        ApplianceConsole::Utilities.bail_if_db_connections("preventing the setup of a database region")
        clear_screen
        say("#{selection}\n\n")
        say("Note: Each database region number must be unique.\n\n")
        region_number = ask_for_integer("database region number")
        clear_screen
        say "It is recommended to use a new database or backup the existing database first.\n"
        say "Warning: SETTING A DATABASE REGION WILL DESTROY ANY EXISTING DATA AND CANNOT BE UNDONE.\n\n"
        if agree("Setting Database Region to: #{region_number}\nAre you sure you want to continue? (Y/N): ")
          say("Setting Database Region...  This process may take a few minutes.\n\n")

          if ApplianceConsole::Utilities.rake("evm:db:region", ["--", {:region => region_number}])
            say("Database region setup complete...")
            say("Start the #{I18n.t("product.name")} server processes via '#{I18n.t("advanced_settings.evmstart")}'.")
          else
            say("Database region setup failed.")
          end
          press_any_key
        else
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.key_gen")
        say("#{selection}\n\n")

        key_config = ApplianceConsole::KeyConfiguration.new
        if key_config.ask_question_loop
          say("\nEncryption key now configured.")
          press_any_key
        else
          say("\nEncryption key not configured.")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.db_config")
        say("#{selection}\n\n")

        key_config = ApplianceConsole::KeyConfiguration.new
        unless key_config.key_exist?
          say "No encryption key found.\n"
          say "For migrations, copy encryption key from a hardened appliance."
          say "For worker and multi-region setups, copy key from another appliance.\n"
          say "If this is your first appliance, just generate one now.\n\n"

          if key_config.ask_question_loop
            say("\nEncryption key now configured.\n\n")
          else
            say("\nEncryption key not configured.")
            press_any_key
            raise MiqSignalError
          end
        end

        loc_selection = ask_with_menu("Database Location", %w(Internal External), nil, false)

        ApplianceConsole::Logging.logger = VMDBLogger.new(LOGFILE)
        database_configuration = ApplianceConsole.const_get("#{loc_selection}DatabaseConfiguration").new
        begin
          database_configuration.ask_questions
        rescue ArgumentError => e
          say("\nConfiguration failed: #{e.message}\n")
          press_any_key
          raise MiqSignalError
        end

        clear_screen
        say "Activating the configuration using the following settings...\n"
        say "#{database_configuration.friendly_inspect}\n"

        if database_configuration.activate
          database_configuration.post_activation
          say("\nConfiguration activated successfully.\n")
          dbhost, database, region = ApplianceConsole::Utilities.db_host_database_region
          press_any_key
        else
          say("\nConfiguration activation failed!\n")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.tmp_config")
        say("#{selection}\n\n")
        tmp_config = ApplianceConsole::TempStorageConfiguration.new
        if tmp_config.ask_questions && tmp_config.activate
          say("Temp storage disk configured")
          press_any_key
        else
          say("Temp storage disk not configured")
          press_any_key
          raise MiqSignalError
        end

      when I18n.t("advanced_settings.restart")
        case ask_with_menu("Restart Option", RE_OPTIONS, nil, false)
        when ApplianceConsole::CANCEL
          # don't do anything
        when RE_RESTART
          if are_you_sure?("restart the appliance now")
            Logging.logger.info("Appliance restart initiated by appliance console.")
            LinuxAdmin::Service.new("evmserverd").stop
            LinuxAdmin::System.reboot!
          end
        when RE_DELLOGS
          if are_you_sure?("restart the appliance now")
            Logging.logger.info("Appliance restart with clean logs initiated by appliance console.")
            LinuxAdmin::Service.new("evmserverd").stop
            LinuxAdmin::Service.new("miqtop").stop
            LinuxAdmin::Service.new("miqvmstat").stop
            LinuxAdmin::Service.new("httpd").stop
            FileUtils.rm_rf(Dir.glob("/var/www/miq/vmdb/log/*.log*"))
            FileUtils.rm_rf(Dir.glob("/var/www/miq/vmdb/log/apache/*.log*"))
            Logging.logger.info("Logs cleaned and appliance rebooted by appliance console.")
            LinuxAdmin::System.reboot!
          end
        end

      when I18n.t("advanced_settings.shutdown")
        say("#{selection}\n\n")
        if are_you_sure?("shut down the appliance now")
          say("\nShutting down appliance...  This process may take a few minutes.\n\n")
          Logging.logger.info("Appliance shutdown initiated by appliance console")
          LinuxAdmin::Service.new("evmserverd").stop
          LinuxAdmin::System.shutdown!
        end

      when I18n.t("advanced_settings.scap")
        say("#{selection}\n\n")
        ApplianceConsole::Scap.new.lockdown
        press_any_key

      when I18n.t("advanced_settings.summary")
        # Do nothing

      when I18n.t("advanced_settings.quit")
        break
      end
    rescue MiqSignalError
      # If a signal is caught anywhere in the inner (after login) loop, go back to the summary screen
      next
    end
  end
end
