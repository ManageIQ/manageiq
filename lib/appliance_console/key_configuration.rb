require 'pathname'
require 'fileutils'
require 'net/scp'
require 'active_support/all'

RAILS_ROOT ||= Pathname.new(File.dirname(__FILE__)).join("../../vmdb")
require 'util/miq-password'

module ApplianceConsole
  CERT_DIR = "#{RAILS_ROOT}/certs"
  KEY_FILE = "#{CERT_DIR}/v2_key"

  class KeyConfiguration
    attr_accessor :host, :login, :password, :key_path, :action, :force

    def initialize(options = {})
      options.each { |k, v| public_send("#{k}=", v) }
      @action   ||= :create
      @login    ||= "root"
      @key_path ||= KEY_FILE
    end

    def ask_questions
      if key_exist?
        @force = agree("Overwrite existing v2_key? (Y/N): ")
        return false unless @force
      end

      @action = ask_for_action(@action)

      if fetch_key?
        say("")
        @host      = ask_for_ip_or_hostname("hostname for appliance with v2_key", @host)
        @login     = ask_for_string("appliance SSH login", @login)
        @password  = ask_for_password("appliance SSH password", @password)
        @key_path  = ask_for_string("path of remote v2_key", @key_path)
      end
      @action
    end

    def ask_question_loop
      loop do
        return false unless ask_questions
        return true if activate
        return false unless agree("Try again?")
      end
    end

    def activate
      return true unless remove_key(force)

      if fetch_key?
        fetch_key
      else
        create_key
      end
      true
    end

    def key_exist?
      File.exist?(KEY_FILE)
    end

    def fetch_key?
      @action == :fetch
    end

    def create_key
      MiqPassword.generate_symmetric(KEY_FILE) && true
    end

    def fetch_key
      # use :verbose => 1 (or :debug for later versions) to see actual errors
      Net::SCP.start(host, login, :password => password) do |scp|
        scp.download!(key_path, KEY_FILE)
      end
      File.exist?(KEY_FILE)
    rescue Net::SSH::AuthenticationFailed => e
      say(e.message)
      false
    end

    private

    def ask_for_action(default_action)
      options = {
        'Create key'                    => :create,
        'Fetch key from remote machine' => :fetch,
      }

      action_id = (options.values.index(default_action).to_i + 1).to_s

      ask_with_menu("Encryption Key", options, action_id, false)
    end

    # return true if key is gone, otherwise false (and we should probably abort)
    # throws an exception if rm fails e.g.: Errno::EACCES
    def remove_key(force)
      !key_exist? || (force && FileUtils.rm(KEY_FILE))
    end
  end
end
