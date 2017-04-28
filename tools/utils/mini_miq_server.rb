#!/usr/bin/env ruby

require "sync"
require "manageiq-gems-pending"
require "active_record"

begin
  lib_files = %w[extensions/as_include_concern pid_file miq_db_config miq_environment]
  lib_files.each { |req| require req }
rescue LoadError
  # Looks like lib isn't in the path, so just load things the hard way
  lib_files.each { |req| require File.expand_path("../../lib/#{req}", File.dirname(__FILE__)) }
end


# HACK:  find a better way to share this code...
begin
  MiqServer
rescue
  module MiqServer
    module WorkerManagement
      module Monitor
        module Kill
        end
      end
    end
  end
end

module Mini
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
    # Duplicate:  app/models/miq_worker.rb:8
    belongs_to :miq_server

    # Duplicate:  app/models/miq_worker.rb:17
    STATUS_CREATING = 'creating'.freeze
    STATUS_STARTING = 'starting'.freeze
    STATUS_STARTED  = 'started'.freeze
    STATUS_READY    = 'ready'.freeze
    STATUS_WORKING  = 'working'.freeze
    STATUS_STOPPING = 'stopping'.freeze
    STATUS_STOPPED  = 'stopped'.freeze
    STATUS_KILLED   = 'killed'.freeze
    STATUS_ABORTED  = 'aborted'.freeze

    STATUSES_STARTING = [STATUS_CREATING, STATUS_STARTING]
    STATUSES_CURRENT  = [STATUS_STARTED, STATUS_READY, STATUS_WORKING]
    STATUSES_STOPPED  = [STATUS_STOPPED, STATUS_KILLED, STATUS_ABORTED]
    STATUSES_CURRENT_OR_STARTING = STATUSES_CURRENT + STATUSES_STARTING

    # Duplicate:  app/models/miq_worker.rb:367
    def kill
      unless pid.nil?
        begin
          _log.info("Killing worker: ID [#{id}], PID [#{pid}], GUID [#{guid}], status [#{status}]")
          Process.kill(9, pid)
        rescue Errno::ESRCH
          _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed")
        rescue => err
          _log.warn("Worker ID [#{id}] PID [#{pid}] GUID [#{guid}] has been killed, but with the following error: #{err}")
        end
      end

      # ActiveRecord::Base.connection.kill(self.sql_spid)
      destroy
    end
  end

  class Zone < ActiveRecord::Base
    has_many :miq_servers
  end

  class AssignedServerRole < ActiveRecord::Base
    belongs_to :miq_server
    belongs_to :server_role
  end

  class ServerRole < ActiveRecord::Base
    has_many :assigned_server_roles
    has_many :miq_servers, :through => :assigned_server_roles
  end

  class MiqServer < ActiveRecord::Base
    STATUS_STARTING       = 'starting'.freeze
    STATUS_STARTED        = 'started'.freeze
    STATUS_RESTARTING     = 'restarting'.freeze
    STATUS_STOPPED        = 'stopped'.freeze
    STATUS_QUIESCE        = 'quiesce'.freeze
    STATUS_NOT_RESPONDING = 'not responding'.freeze
    STATUS_KILLED         = 'killed'.freeze

    STATUSES_STOPPED = [STATUS_STOPPED, STATUS_KILLED]
    STATUSES_ACTIVE  = [STATUS_STARTING, STATUS_STARTED]
    STATUSES_ALIVE   = STATUSES_ACTIVE + [STATUS_RESTARTING, STATUS_QUIESCE]

    class << self
      include MiqDbConfig
    end


    # Dup definitiion:  app/models/miq_server/worker_management.rb:9
    has_many :miq_workers
    # Dup definitiion:  app/models/miq_server/role_management.rb:9
    has_many :assigned_server_roles, :dependent => :destroy
    has_many :server_roles,   :through => :assigned_server_roles
    has_many :active_roles,   -> { where('assigned_server_roles.active' => true) }, :through => :assigned_server_roles, :source => :server_role
    belongs_to              :zone

    MIQ_ROOT = File.expand_path("../..", File.dirname(__FILE__)).to_s.freeze

    #
    # Modified from tools/fix_auth/fix_auth.rb:fix_database_passwords
    #
    # Not sure if this is re-usable or not with that code
    #
    def self.with_temporary_connection
      begin
        ActiveRecord::Base.connection_config
      rescue ActiveRecord::ConnectionNotEstablished
        # not configured, lets try again
        ActiveRecord::Base.logger = Logger.new("#{MIQ_ROOT}/log/mini_miq_server.log")
        new_connection = true
      end

      begin
        rails_env = ENV["RAILS_ENV"] || "development"
        ActiveRecord::Base.establish_connection(database_configuration[rails_env]) if new_connection
        yield
      ensure
        ActiveRecord::Base.clear_active_connections! if new_connection
      end
    end

    # Don't used cached_with_timeout for this... excessive since this shouldn't
    # be used for more then starting up a process.  Consider caching this with a
    # class var though.
    def self.my_server(skip_cache=false)
      find_by(:guid => my_guid)
    end

    # vvvvv Duplicate Code vvvvv
    # vvvvvvvvvvvvvvvvvvvvvvvvvv

    # Dup definitiion:  app/models/miq_server/worker_management.rb:13
    def self.kill_all_workers
      svr = my_server(true)
      svr.kill_all_workers unless svr.nil?
    end

    def self.pidfile
      @pidfile ||= "#{MIQ_ROOT}/tmp/pids/evm.pid"
    end

    def self.running?
      p = PidFile.new(pidfile)
      p.running? ? p.pid : false
    end

    # From app/models/miq_server/role_management.rb:174
    def active_role_names
      active_roles.collect(&:name).sort
    end

    #
    # Zone and Role methods
    #
    def self.my_guid
      @@my_guid_cache ||= begin
        guid_file = File.join(MIQ_ROOT, "GUID")
        File.write(guid_file, MiqUUID.new_guid) unless File.exist?(guid_file)
        File.read(guid_file).strip
      end
    end

    def stop_poll
      # ::Settings.server.stop_poll.to_i_with_method
      10.seconds
    end

    def stop(sync = false)
      return if self.stopped?

      shutdown_and_exit_queue
      wait_for_stopped if sync
    end

    def wait_for_stopped
      loop do
        reload
        break if self.stopped?
        sleep stop_poll
      end
    end

    def self.stop(sync = false)
      require_relative "mini_miq_queue"
      # require "more_core_extensions/core_ext/shared/nested"
      # require 'vmdb/plugins'
      # require 'vmdb/settings'
      # Vmdb::Settings.init
      # Vmdb::Loggers.apply_config(::Settings.log)

      svr = my_server(true) rescue nil
      svr.stop(sync) unless svr.nil?
      PidFile.new(pidfile).remove
    end

    def enqueue_for_server(method_name)
      MiqQueue.put_unless_exists(
        :class_name  => "MiqServer",
        :instance_id => id,
        :queue_name  => 'miq_server',
        :zone        => zone.name,
        :method_name => method_name,
        :server_guid => guid
      )
    end

    def shutdown_and_exit_queue
      enqueue_for_server('shutdown_and_exit')
    end

    def is_local?
      guid == MiqServer.my_guid
    end

    def is_remote?
      !is_local?
    end

    def stopped?
      STATUSES_STOPPED.include?(status)
    end

    # Dup definitiion:  app/models/miq_server/worker_management.rb:19
    def setup_drb_variables
      @workers_lock        = Sync.new
      @workers             = {}

      @queue_messages_lock = Sync.new
      @queue_messages      = {}
    end

    # Dup definitiion:  app/models/miq_server/worker_management.rb:27
    def start_drb_server
      require 'drb'
      require 'drb/acl'

      setup_drb_variables

      acl = ACL.new(%w( deny all allow 127.0.0.1/32 ))
      DRb.install_acl(acl)

      drb = DRb.start_service("druby://127.0.0.1:0", self)
      update_attributes(:drb_uri => drb.uri)
    end

    # Dup definitiion:  app/models/miq_server/worker_management.rb:40
    def worker_add(worker_pid)
      @workers_lock.synchronize(:EX) { @workers[worker_pid] ||= {} } unless @workers_lock.nil?
    end

    # Dup definitiion:  app/models/miq_server/worker_management.rb:44
    def worker_delete(worker_pid)
      @workers_lock.synchronize(:EX) { @workers.delete(worker_pid) } unless @workers_lock.nil?
    end
  end
end

# HACK:  find a better way to share this code...
begin
  MiqWorker
rescue
  MiqWorker = Mini::MiqWorker
end

# puts Mini::MiqServer.with_temporary_connection { Mini::MiqServer.my_server.inspect }
