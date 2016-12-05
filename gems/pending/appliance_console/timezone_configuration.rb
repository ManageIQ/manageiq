require "linux_admin"
require "appliance_console/logging"
require 'appliance_console/prompts'

module ApplianceConsole
  class TimezoneConfiguration
    include ApplianceConsole::Logging

    attr_reader   :current_timzone
    attr_accessor :new_timezone

    def initialize(region_timezone_string)
      @current_timezone = region_timezone_string
    end

    def activate
      log_and_feedback(__method__) do
        say("Applying new timezone #{new_timezone}...")
        begin
          LinuxAdmin::TimeDate.system_timezone = new_timezone
        rescue LinuxAdmin::TimeDate::TimeCommandError => e
          say("Failed to apply timezone configuration")
          Logging.logger.error("Failed to timezone configuration: #{e.message}")
          return false
        end
      end
      true
    end

    def ask_questions
      ask_for_timezone && confirm
    end

    def ask_for_timezone
      current_item = timezone_hash

      while current_item.is_a?(Hash)
        selection = ask_with_menu("Geographic Location", current_item.keys, nil, false)
        return false if selection == CANCEL
        current_item = current_item[selection]
      end

      @new_timezone = current_item
      true
    end

    def confirm
      clear_screen
      agree("Change the timezone to #{new_timezone}? (Y/N): ")
    end

    def timezone_hash
      LinuxAdmin::TimeDate.timezones.each_with_object({}) do |tz, hash|
        hash.store_path(*tz.split("/"), tz)
      end
    end
  end # class TimezoneConfiguration
end # module ApplianceConsole
