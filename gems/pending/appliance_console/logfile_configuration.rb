require 'linux_admin'
require 'pathname'
require 'fileutils'
require 'appliance_console/logical_volume_management'
require 'appliance_console/prompts'

module ApplianceConsole
  class LogfileConfiguration
    LOGFILE_DIRECTORY = Pathname.new("/var/www/miq/vmdb/log").freeze
    LOGFILE_NAME = "miq_logs".freeze

    attr_accessor :disk

    include ApplianceConsole::Logging

    def activate
      stop_evm
      initialize_logfile_disk
      start_evm
    end

    def ask_questions
      clear_screen
      return false unless use_new_disk
      choose_disk
      confirm_selection
    end

    private

    def confirm_selection
      agree("Continue with disk: #{disk.path}: #{disk.size.to_i / 1.megabyte} MB (Y/N):")
    end

    def use_new_disk
      agree("Configure a new logfile disk volume? (Y/N):")
    end

    def choose_disk
      self.disk = ask_for_disk("logfile disk")
    end

    def initialize_logfile_disk
      say 'Initializing logfile disk'
      LogicalVolumeManagement.new(:disk => disk, :mount_point => LOGFILE_DIRECTORY, :name => LOGFILE_NAME).setup

      FileUtils.mkdir_p("#{LOGFILE_DIRECTORY}/apache")
      AwesomeSpawn.run!('/usr/sbin/semanage fcontext -a -t httpd_log_t "#{LOGFILE_DIRECTORY.to_path}(/.*)?"')
      AwesomeSpawn.run!("/sbin/restorecon -R -v #{LOGFILE_DIRECTORY.to_path}") if File.executable?("/sbin/restorecon")
      true
    end

    def start_evm
      say 'Starting EVM'
      LinuxAdmin::Service.new("evmserverd").enable.start
      LinuxAdmin::Service.new("httpd").enable.start
    end

    def stop_evm
      say 'Stopping EVM'
      LinuxAdmin::Service.new("evmserverd").stop
      LinuxAdmin::Service.new("httpd").stop
    end
  end
end
