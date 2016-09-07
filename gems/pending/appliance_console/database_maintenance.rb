require 'appliance_console/logging'
require 'appliance_console/prompts'
require 'fileutils'

module ApplianceConsole
  class DatabaseMaintenance
    include ApplianceConsole::Logging

    HOURLY_CRON = "/etc/cron.hourly/miq-pg-maintenance-hourly.cron".freeze

    def ask_questions
      clear_screen
      confirm
    end

    def activate
      say("Configuring Database Maintenance...")
      if hourly_configured?
        deactivate_hourly
      else
        configure_hourly
      end
    end

    private

    def configure_hourly
      say("Configuring Hourly Database Maintenance...")
      write_hourly_cron
      FileUtils.chmod(0755, HOURLY_CRON)
      true
    end

    def confirm
      if hourly_configured?
        agree("Hourly Database Maintenance is already configured, Un-Configure (Y/N):")
      else
        agree("Configure Database Maintenance? (Y/N): ")
      end
    end

    def deactivate_hourly
      FileUtils.rm_f(HOURLY_CRON)
      true
    end

    def hourly_configured?
      File.exist?(HOURLY_CRON)
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
