module VMDB
  module Initializer
    def self.init
      log_prefix = "VMDB::Initializer.init"
      $log.info "#{log_prefix} - Program Name: #{$PROGRAM_NAME}, PID: #{Process.pid}, ENV['MIQ_GUID']: #{ENV['MIQ_GUID']}, ENV['EVMSERVER']: #{ENV['EVMSERVER']}"

      if MiqEnvironment::Process.is_web_server_worker?
        require 'haml-rails'

        # Make these constants globally available
        ::UiConstants
      end

      # When these classes are deserialized in ActiveRecord (e.g. EmsEvent, MiqQueue), they need to be preloaded
      require 'VimTypes'

      ####################################################
      # If UiWorker called in Development Mode
      #   invoked via command line -- script/server
      #   invoked via debugger     -- using rdebug-ide gem
      #
      # Then, set up VMDB as if called from MiqServer:
      #   1. SEED the MUST-HAVE classes
      #   2. Mark current server as started
      #
      ####################################################
      if MiqEnvironment::Process.is_ui_worker_via_command_line?
        Vmdb::Logging.apply_config
        EvmDatabase.seed_primordial
        MiqServer.my_server.starting_server_record
        MiqServer.my_server.update_attributes(:status => "started")
      end

      if MiqEnvironment::Process.is_web_server_worker?
        Vmdb::Application.config.secret_token = MiqDatabase.first.session_secret_token
      end

      ####################################################
      # If this is intended to field Rails requests (called via mongrel_rails start),
      # Then start a UiWorker, so that it can be monitored
      ####################################################
      if MiqEnvironment::Process.is_ui_worker_via_evm_server?
        require "#{Rails.root}/lib/workers/ui_worker.rb"

        # Do all the SQL worker preparation in the main thread
        ui_worker = UiWorker.new.prepare

        # The heartbeating will be done in a separate thread
        Thread.new { ui_worker.run }
      end

      if MiqEnvironment::Process.is_web_service_worker_via_evm_server?
        require "#{Rails.root}/lib/workers/web_service_worker.rb"

        # Do all the SQL worker preparation in the main thread
        ws_worker = WebServiceWorker.new.prepare

        # The heartbeating will be done in a separate thread
        Thread.new { ws_worker.run }
      end
    end

    def self.get_network
      # to call this method use: VMDB::Initializer.get_network
      retVal = {}
      miqnet = "/bin/miqnet.sh"

      if File.exists?(miqnet)
        # Make a call to the virtual appliance to get the network information
        cmd     = "#{miqnet} -GET"
        netinfo = `#{cmd}`
        raise "Unable to execute command: #{cmd}" if netinfo.nil?
        netinfo = netinfo.split

        [:hostname, :macaddress, :ipaddress, :netmask, :gateway, :primary_dns, :secondary_dns].each do |type|
          retVal[type] = netinfo.shift
        end
      end

      retVal
    end

    def self.set_network(options)
      raise ":mode parameter missing in options." if options.nil? or options[:mode].nil?

      # Make a call to the virtual appliance to set the network information
      if options[:mode] == "DHCP"
        retVal = `/bin/miqnet.sh -DHCP > /dev/null 2>&1 ; echo $?`.chomp
      elsif options[:mode] == "STATIC"
        staticParams = ""

        [:ipaddress, :netmask, :gateway, :primary_dns, :secondary_dns].each do |type|
          raise "#{type} is required." if type != :secondary_dns and options[type].blank?
          staticParams += options[type] + " "
        end

        retVal = `/bin/miqnet.sh -STATIC ${staticParams} > /dev/null 2>&1 ; echo $?`.chomp
      else
        raise ":mode must be 'DHCP' or 'STATIC'."
      end

      retVal == 0
    end

  end
end
