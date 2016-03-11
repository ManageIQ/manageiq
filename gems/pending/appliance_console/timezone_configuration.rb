require "appliance_console/logging"
require 'appliance_console/prompts'

module ApplianceConsole
  class TimezoneConfiguration
    # Timezone constants
    TZ_AREAS         = %w(Africa America Asia Atlantic Australia Canada Europe Indian Pacific US).freeze
    TZ_AREAS_OPTIONS = ["United States", "Canada", "Africa", "America", "Asia", "Atlantic Ocean", "Australia", "Europe",
                        "Indian Ocean", "Pacific Ocean", CANCEL].freeze
    TZ_AREAS_MAP     = Hash.new { |_h, k| k }.merge!(
      "United States"  => "US",
      "Atlantic Ocean" => "Atlantic",
      "Pacific Ocean"  => "Pacific",
      "Indian Ocean"   => "Indian"
    ).freeze
    TZ_AREAS_MAP_REV = Hash.new { |_h, k| k }.merge!(TZ_AREAS_MAP.invert).freeze

    attr_reader   :cur_city, :cur_loc, :timezone, :tzdata
    attr_accessor :new_city, :new_loc, :tz_area

    include ApplianceConsole::Logging

    def initialize(region_timezone_string)
      @timezone = region_timezone_string.split("/")
      @cur_loc  = timezone[0]
      @cur_city = timezone[1..-1].join("/")
      @new_loc  = nil
      @new_city = nil
      @tz_area = nil

      @tzdata = {}
      TZ_AREAS.each do |a|
        @tzdata[a] = ary = []
        a = "/usr/share/zoneinfo/#{a}/"
        Dir.glob("#{a}*").each do |z|
          ary << z[a.length..-1]
        end
        ary.sort!
      end
    end

    def activate
      log_and_feedback(__method__) do
        say("Applying timezone to #{new_loc}/#{new_city}...")
        begin
          LinuxAdmin::TimeDate.system_timezone = "#{new_loc}/#{new_city}"
        rescue LinuxAdmin::TimeDate::TimeCommandError => e
          say("Failed to apply timezone configuration")
          Logging.logger.error("Failed to timezone configuration: #{e.message}")
          return false
        end
      end
      true
    end

    def ask_questions
      ask_timezone_area &&
        ask_timezone_city &&
        confirm
    end

    def ask_timezone_area
      # Prompt for timezone geographic area (with current area as default)
      def_loc = TZ_AREAS.include?(cur_loc) ? TZ_AREAS_MAP_REV[cur_loc] : nil
      @tz_area = ask_with_menu("Geographic Location", TZ_AREAS_OPTIONS, def_loc, false)
      return false if tz_area == CANCEL
      @new_loc = TZ_AREAS_MAP[tz_area]
      true
    end

    def ask_timezone_city
      # Prompt for timezone specific city (with current city as default)
      default_city = cur_city if tzdata[new_loc].include?(cur_city) && cur_loc == new_loc
      @new_city = ask_with_menu("Timezone", tzdata[new_loc], default_city, true) do |menu|
        menu.list_option = :columns_across
      end
      new_city != CANCEL
    end

    def confirm
      clear_screen
      say(<<-EOL)
Timezone Configuration

        Timezone area: #{tz_area}
        Timezone city: #{new_city}

        EOL

      agree("Apply timezone configuration? (Y/N): ")
    end
  end # class TimezoneConfiguration
end # module ApplianceConsole
