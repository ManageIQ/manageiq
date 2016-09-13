require 'appliance_console/logging'
require 'appliance_console/prompts'

module ApplianceConsole
  class DatabaseMaintenancePeriodic
    include ApplianceConsole::Logging

    RUN_AS           = 'root'.freeze
    PERIODIC_CMD     = '/usr/bin/periodic_vacuum_full_tables'.freeze
    CRONTAB_FILE     = '/etc/crontab'.freeze
    SCHEDULE_PROMPT  = 'frequency periodic database maintenance should run (hourly daily weekly monthly)'.freeze
    HOUR_PROMPT      = 'hour number (0..23)'.freeze
    WEEK_DAY_PROMPT  = 'week day number (0..6, where Sunday is 0)'.freeze
    MONTH_DAY_PROMPT = 'month day number (1..31)'.freeze

    attr_accessor :crontab_schedule_expression, :already_configured, :requested_deactivate, :requested_activate

    def initialize
      self.crontab_schedule_expression = nil
      self.already_configured = File.readlines(CRONTAB_FILE).detect { |line| line =~ /#{PERIODIC_CMD}/ }.present?
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
        self.requested_deactivate = agree("Periodic Database Maintenance is already configured, Un-Configure (Y/N):")
      else
        self.requested_activate = agree("Configure Periodic Database Maintenance? (Y/N): ")
        ask_for_schedule if requested_activate
      end
    end

    private

    def ask_for_schedule
      self.crontab_schedule_expression =
        case ask_for_schedule_frequency(SCHEDULE_PROMPT, 'monthly')
        when 'hourly'
          generate_hourly_crontab_expression
        when 'daily'
          generate_daily_crontab_expression
        when 'weekly'
          generate_weekly_crontab_expression
        when 'monthly'
          generate_monthly_crontab_expression
        end
    end

    def configure
      File.open(CRONTAB_FILE, "a") do |f|
        f.write("#{crontab_schedule_expression} #{RUN_AS} #{PERIODIC_CMD}\n")
      end
      true
    end

    def deactivate
      keep_content = File.readlines(CRONTAB_FILE).reject { |line| line =~ /#{PERIODIC_CMD}/ }
      File.open(CRONTAB_FILE, "w") { |f| keep_content.each { |line| f.puts line } }
      true
    end

    def generate_hourly_crontab_expression
      "0 * * * *"
    end

    def generate_daily_crontab_expression
      "0 #{ask_for_hour_number(HOUR_PROMPT)} * * *"
    end

    def generate_weekly_crontab_expression
      "0 #{ask_for_hour_number(HOUR_PROMPT)} * * #{ask_for_week_day_number(WEEK_DAY_PROMPT)}"
    end

    def generate_monthly_crontab_expression
      "0 #{ask_for_hour_number(HOUR_PROMPT)} #{ask_for_month_day_number(MONTH_DAY_PROMPT)} * *"
    end
  end # class DatabaseMaintenancePeriodic
end # module ApplianceConsole
