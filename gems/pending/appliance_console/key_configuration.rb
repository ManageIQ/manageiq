require 'pathname'
require 'fileutils'
require 'net/scp'
require 'active_support/all'

RAILS_ROOT ||= Pathname.new(__dir__).join("../../..")
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
        @force = agree("Overwrite existing encryption key (v2_key)? (Y/N): ")
        return false unless @force
      end

      @action = ask_for_action(@action)

      if fetch_key?
        say("")
        @host      = ask_for_ip_or_hostname("hostname for appliance with encryption key (v2_key)", @host)
        @login     = ask_for_string("appliance SSH login", @login)
        @password  = ask_for_password("appliance SSH password", @password)
        @key_path  = ask_for_string("path of remote encryption key (v2_key)", @key_path)
      end
      @action
    end

    def ask_question_loop
      loop do
        return false unless ask_questions
        return true if activate
        return false unless agree("Try again? (Y/N) ")
      end
    end

    def activate
      if remove_key(force)
        if fetch_key?
          fetch_key
        else
          create_key
        end
      else
        # probably only got here via the cli
        $stderr.puts
        $stderr.puts "Only generate one encryption key (v2_key) per installation."
        $stderr.puts "Chances are you did not want to overwrite this file."
        $stderr.puts "If you do this all encrypted secrets in the database will not be readable."
        $stderr.puts "Please backup your key and run this command again with --force-key."
        $stderr.puts
        false
      end
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
      options = {'Create key' => :create, 'Fetch key from remote machine' => :fetch}
      ask_with_menu("Encryption Key", options, default_action, false)
    end

    # return true if key is gone, otherwise false (and we should probably abort)
    # throws an exception if rm fails e.g.: Errno::EACCES
    def remove_key(force)
      !key_exist? || (force && FileUtils.rm(KEY_FILE))
    end
  end
end
