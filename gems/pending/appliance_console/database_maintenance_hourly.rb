require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'fileutils'

module ApplianceConsole
  class DatabaseMaintenanceHourly
    include ApplianceConsole::Logging

    HOURLY_CRON = "/etc/cron.hourly/miq-pg-maintenance-hourly.cron".freeze

    attr_accessor :already_configured, :requested_deactivate, :requested_activate

    def initialize
      self.already_configured = File.exist?(HOURLY_CRON)
      self.requested_deactivate = false
      self.requested_activate = false
    end

    def activate
      return deactivate if requested_deactivate
      return configure if requested_activate
      false
    end

    def confirm
      if already_configured
        self.requested_deactivate = agree("Hourly Database Maintenance is already configured, Un-Configure (Y/N):")
      else
        self.requested_activate = agree("Configure Hourly Database Maintenance? (Y/N): ")
      end
    end

    private

    def configure
      say("Configuring Hourly Database Maintenance...")
      write_hourly_cron
      FileUtils.chmod(0755, HOURLY_CRON)
      true
    end

    def deactivate
      say("Un-Configuring Hourly Database Maintenance...")
      FileUtils.rm_f(HOURLY_CRON)
      true
    end

    def write_hourly_cron
      File.open(HOURLY_CRON, "w") do |f|
        f.write("#!/bin/sh\n")
        f.write("/usr/bin/hourly_reindex_metrics_tables\n")
        f.write("/usr/bin/hourly_reindex_miq_queue_table\n")
        f.write("/usr/bin/hourly_reindex_miq_workers_table\n")
        f.write("exit 0\n")
      end
    end
  end # class DatabaseMaintenance < DatabaseConfiguration
end # module ApplianceConsole
