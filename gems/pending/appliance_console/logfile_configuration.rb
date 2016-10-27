require 'linux_admin'
require 'pathname'
require 'fileutils'
require 'util/miq-system.rb'
require 'appliance_console/logical_volume_management'
require 'appliance_console/prompts'

module ApplianceConsole
  class LogfileConfiguration
    LOGFILE_DIRECTORY = Pathname.new("/var/www/miq/vmdb/log").freeze
    LOGFILE_NAME = "miq_logs".freeze
    MIQ_LOGS_CONF = Pathname.new("/etc/logrotate.d/miq_logs.conf").freeze

    attr_accessor :size, :disk, :current_logrotate_count, :new_logrotate_count

    include ApplianceConsole::Logging

    def initialize
      self.disk                = nil
      self.new_logrotate_count = nil

      self.size = MiqSystem.disk_usage(LOGFILE_DIRECTORY)[0][:total_bytes]
      self.current_logrotate_count = /rotate\s+(\d+)/.match(File.read(MIQ_LOGS_CONF))[1]
    end

    def activate
      activate_new_disk && activate_new_logrotate_count
    end

    def ask_questions
      clear_screen
      choose_disk if use_new_disk
      choose_logrotate_count if set_new_logrotate_count?
      confirm_selection
    end

    private

    def confirm_selection
      return false unless disk || new_logrotate_count

      clear_screen
      if disk
        say("\t#{disk.path} with #{disk.size.to_i / 1.gigabyte} GB will be configured as the new logfile disk.")
      end

      if new_logrotate_count
        say("\tThe number of saved logratations will be updated to: #{new_logrotate_count}")
      end

      agree("Confirm continue with these updates (Y/N):")
    end

    def use_new_disk
      agree("Configure a new logfile disk volume? (Y/N):")
    end

    def choose_disk
      self.disk = ask_for_disk("logfile disk")
    end

    def set_new_logrotate_count?
      agree("Change the saved logrotate count from #{current_logrotate_count}? (Y/N):")
    end

    def choose_logrotate_count
      say "\t1 GB of disk space is recommended for each saved log rotation."
      if disk
        say "\tThe proposed new disk is #{disk.size.to_i / 1.gigabyte} GB"
      else
        say "\tThe current log disk is #{size.to_i / 1.gigabyte} GB"
      end

      self.new_logrotate_count = ask_for_integer("new log rotate count")
    end

    def activate_new_logrotate_count
      return true unless new_logrotate_count
      say 'Activating new logrotate count'
      data = File.read(MIQ_LOGS_CONF)
      data.gsub!(/rotate\s+\d+/, "rotate #{new_logrotate_count}")
      File.write(MIQ_LOGS_CONF, data)
      true
    end

    def activate_new_disk
      return true unless disk
      stop_evm
      initialize_logfile_disk
      start_evm
      true
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
