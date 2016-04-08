require 'pathname'
require 'fileutils'
require 'appliance_console/errors'
require 'appliance_console/utilities'
require 'appliance_console/logging'

RAILS_ROOT ||= Pathname.new(__dir__).join("../../..")

module ApplianceConsole
  class ExternalAuthOptions
    # VMDB_YML      = RAILS_ROOT.join("config/vmdb.yml.db")
    # VMDB_YML_TMPL = RAILS_ROOT.join("config/vmdb.tmpl.yml")

    AUTH_PATH = "/authentication".freeze

    EXT_AUTH_OPTIONS = {
      "#{AUTH_PATH}/sso_enabled"          => {:label => "Single Sign-On", :logic => true},
      "#{AUTH_PATH}/saml_enabled"         => {:label => "SAML",           :logic => true},
      "#{AUTH_PATH}/local_login_disabled" => {:label => "Local Login",    :logic => false}
    }.freeze

    include ApplianceConsole::Logging

    def initialize
      @updates = {}
      @current_config = {}
    end

    def ask_questions
      @current_config = load_current
      apply = EXT_AUTH_OPTIONS.keys.count + 1
      skip = apply + 1
      selection = 0
      while selection < apply
        say("\nChoose External Authentication Options to update:")
        cnt = 1
        EXT_AUTH_OPTIONS.keys.each do |key|
          current_state = selected_value(key)
          say("#{cnt}) #{selected_verb(key, !current_state)} #{EXT_AUTH_OPTIONS[key][:label]}")
          cnt += 1
        end
        say("#{apply}) Apply updates")
        say("#{skip}) Skip updates")
        show_updates
        selection = ask_for_integer("Choose option 1-#{skip}", 1..skip)
        if selection < apply
          key = EXT_AUTH_OPTIONS.keys[selection - 1]
          @updates[key] = !selected_value(key)
        end
      end
      @updates = {} if selection == skip
      true
    end

    def show_updates
      updates_todo = ""
      EXT_AUTH_OPTIONS.keys.each do |key|
        next unless @updates.key?(key)
        updates_todo << ", " if updates_todo.present?
        updates_todo << " #{selected_verb(key, @updates[key])} #{EXT_AUTH_OPTIONS[key][:label]}"
      end
      updates_to_apply = updates_todo.present? ? "Updates to apply: #{updates_todo}" : ""
      say("\n#{updates_to_apply}")
    end

    def selected_value(key)
      return @updates[key] if @updates.key?(key)
      return @current_config[key] if @current_config.key?(key)
      false
    end

    def selected_verb(key, flag)
      if EXT_AUTH_OPTIONS[key][:logic]
        flag ? "Enable" : "Disable"
      else
        flag ? "Disable" : "Enable"
      end
    end

    def any_updates?
      @updates.present?
    end

    def update_configuration(update_hash = nil)
      update_hash ||= @updates
      if update_hash.present?
        say("\nUpdating external authentication options on appliance ...")
        params = update_hash.collect { |key, value| "#{key}=#{value}" }
        result = ApplianceConsole::Utilities.rake_run("evm:settings:set", params)
        raise parse_errors(result).join(', ') if result.failure?
      end
    end

    # extauth_opts option parser: syntax is key=value,key=value
    #   key is one of the EXT_AUTH_OPTIONS keys.
    #   value is one of 1, true, 0 or false.
    #
    def parse(options)
      parsed_updates = {}
      options.split(",").each do |keyval|
        key, val = keyval.split('=')
        key, val = normalize_key(key.to_s.strip), val.to_s.strip
        unless EXT_AUTH_OPTIONS.key?(key)
          message = "Unknown external authentication option #{key} specified"
          message << ", supported options are #{EXT_AUTH_OPTIONS.keys.join(', ')}"
          raise message
        end

        value = option_value(val)
        raise("Invalid #{key} option value #{val} specified, must be true or false") if value.nil?
        parsed_updates[key] = value
      end
      parsed_updates
    end

    def self.configured?
      # DB Up and running
      true
    end

    private

    def load_current
      say("\nFetching external authentication options from appliance ...")
      result = ApplianceConsole::Utilities.rake_run("evm:settings:get", EXT_AUTH_OPTIONS.keys)

      if result.success?
        return parse_response(result)
      else
        raise parse_errors(result).join(', ')
      end
    end

    def parse_errors(result)
      result.error.split("\n").collect { |line| line if line =~ /^error: /i }.compact
    end

    def normalize_key(key)
      key.include?('/') ? key : "#{AUTH_PATH}/#{key}"
    end

    def parse_response(result)
      result.output.split("\n").each_with_object({}) do |line, hash|
        key, val = line.split("=")
        hash[key] = parse_value(val)
      end
    end

    def option_value(value)
      return true  if value == '1' || value =~ /true/i
      return false if value == '0' || value =~ /false/i
      nil
    end

    def parse_value(value)
      value.present? ? option_value(value) : false
    end
  end
end
