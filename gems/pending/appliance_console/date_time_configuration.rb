require "appliance_console/logging"
require 'appliance_console/prompts'

module ApplianceConsole
  class DateTimeConfiguration
    DATE_REGEXP   = /^(2[0-9]{3})-(0?[1-9]|1[0-2])-(0?[1-9]|[12][0-9]|3[01])/
    DATE_PROMPT   = "current date (YYYY-MM-DD)".freeze
    TIME_REGEXP   = /^(0?[0-9]|1[0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9])/
    TIME_PROMPT   = "current time in 24 hour format (HH:MM:SS)".freeze

    attr_accessor :new_date, :new_time, :manual_time_sync

    include ApplianceConsole::Logging

    def initialize
      @new_date         = nil
      @new_time         = nil
      @manual_time_sync = false
    end

    def activate
      say("Applying time configuration...")
      establish_auto_sync &&
        configure_date_time
    end

    def ask_questions
      ask_establish_auto_sync
      ask_for_date &&
        ask_for_time &&
        confirm
    end

    def ask_establish_auto_sync
      say("Automatic time synchronization must be disabled to manually set date or time\n\n")

      @manual_time_sync = agree(<<-EOL)
Yes to disable Automatic time synchronization and prompt for date and time.
 No to enable  Automatic time synchronization.  (Y/N):

        EOL
    end

    def ask_for_date
      return true unless manual_time_sync
      @new_date = just_ask(DATE_PROMPT, nil, DATE_REGEXP)
      true
    rescue
      false
    end

    def ask_for_time
      return true unless manual_time_sync
      @new_time = just_ask(TIME_PROMPT, nil, TIME_REGEXP)
      true
    rescue
      false
    end

    def confirm
      manual_time_sync ? confirm_manual : confirm_auto
    end

    def confirm_auto
      clear_screen
      say("Date and Time Configuration will be automatic")

      agree("Apply automatic time configuration? (Y/N): ")
    end

    def confirm_manual
      clear_screen
      say(<<-EOL)
Date and Time Configuration

        Date: #{new_date}
        Time: #{new_time}

        EOL

      agree("Apply manual time configuration? (Y/N): ")
    end

    def establish_auto_sync
      manual_time_sync ? disable_auto_sync : enable_auto_sync
    end

    def enable_auto_sync
      LinuxAdmin::Service.new("chronyd").enable.start
      LinuxAdmin::Service.new("systemd-timedated").restart
      true
    rescue => e
      say("Failed to enable time synchronization")
      Logging.logger.error("Failed to enable time synchronization: #{e.message}")
      false
    end

    def disable_auto_sync
      LinuxAdmin::Service.new("chronyd").stop.disable
      LinuxAdmin::Service.new("systemd-timedated").restart
      true
    rescue => e
      say("Failed to disable time synchronization")
      Logging.logger.error("Failed to disable time synchronization: #{e.message}")
      false
    end

    def configure_date_time
      return true unless manual_time_sync
      LinuxAdmin::TimeDate.system_time = Time.parse("#{new_date} #{new_time}").getlocal
      true
    rescue => e
      say("Failed to apply time configuration")
      Logging.logger.error("Failed to apply time configuration: #{e.message}")
      false
    end
  end # class TimezoneConfiguration
end # module ApplianceConsole
