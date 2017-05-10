#!/usr/bin/env ruby

require "sync"
require "manageiq-gems-pending"
require "active_record"

# Files from lib/
begin
  lib_files = %w[miq_helper miq_environment pid_file vmdb/settings/walker extensions/as_include_concern extensions/miq_db_config]
  lib_files.each { |req| require req }
rescue LoadError
  # Looks like lib isn't in the path, so just load things the hard way
  lib_files.each { |req| require File.expand_path("../../lib/#{req}", File.dirname(__FILE__)) }
end

# Files from app/models/
begin
  lib_files = %w(miq_server/base_constants miq_server/base_methods miq_server/worker_management_base miq_server/queue_management)
  lib_files.each { |req| require req }
rescue LoadError
  # Looks like lib isn't in the path, so just load things the hard way
  lib_files.each { |req| require File.expand_path("../../app/models/#{req}", File.dirname(__FILE__)) }
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
    extend MiqDbConfig
    include MiqServerBaseConstants
    include MiqServerBaseMethods
    include MiqServerWorkerManagementBase
    include MiqServerQueueManagement

    # puts self.methods.grep(/kill/).inspect
    # puts self.name

    # Dup definitiion:  app/models/miq_server/role_management.rb:9
    has_many :assigned_server_roles, :dependent => :destroy
    has_many :server_roles,   :through => :assigned_server_roles
    has_many :active_roles,   -> { where('assigned_server_roles.active' => true) }, :through => :assigned_server_roles, :source => :server_role
    belongs_to :zone

    def self.queue_class
      Mini::MiqQueue
    end

    # Modified from tools/fix_auth/fix_auth.rb:fix_database_passwords
    #
    # Not sure if this is re-usable or not with that code, but basically
    # establishes a connect for ActiveRecord if one doesn't exist, and executes
    # the block, terminating the connection afterwards if one needed to be
    # created.
    def self.with_temporary_connection
      begin
        ActiveRecord::Base.connection_config
      rescue ActiveRecord::ConnectionNotEstablished
        # not configured, lets try again
        ActiveRecord::Base.logger = Logger.new(Miq.root.join("log", "mini_miq_server.log"))
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

    # From app/models/miq_server/role_management.rb:174
    def active_role_names
      active_roles.collect(&:name).sort
    end

    # TODO:  Determine if it is worth it to make this work with Settings
    def stop_poll
      # ::Settings.server.stop_poll.to_i_with_method
      10.seconds
    end

    def self.stop(sync = false)
      # Don't require this until it is needed, basically
      #
      # MiqQueue code isn't needed for start/status
      require_relative "mini_miq_queue"

      super
    end
  end
end

# puts Mini::MiqServer.with_temporary_connection { Mini::MiqServer.my_server.inspect }
