class VmdbDatabaseConnection < ActsAsArModel
  virtual_column :address,           :type => :string
  virtual_column :application,       :type => :string
  virtual_column :command,           :type => :string
  virtual_column :spid,              :type => :integer
  virtual_column :task_state,        :type => :string
  virtual_column :wait_resource,     :type => :string
  virtual_column :wait_time,         :type => :integer
  virtual_column :vmdb_database_id,  :type => :integer

  virtual_belongs_to :vmdb_database
  virtual_belongs_to :zone
  virtual_belongs_to :miq_server
  virtual_belongs_to :miq_worker

  virtual_column :pid, :type => :integer
  virtual_column :blocked_by, :type => :integer

  attr_accessor :vmdb_database_id

  def initialize(record)
    self.vmdb_database = self.class.vmdb_database
    @record = record
  end

  def address
    @record.client_addr
  end

  def application
    @record.application_name
  end

  def command
    @record.query
  end

  def spid
    @record.pid
  end

  def task_state
    @record.waiting
  end

  def wait_time
    @record.wait_time_ms
  end

  def wait_resource
    @record.pg_locks.first.relation
  end

  #
  # Attributes and Reflections
  #

  def model_name
    self.name.singularize.camelize
  end

  def model
    return @model if instance_variable_defined?(:@model)
    @model = self.model_name.constantize rescue nil
  end

  def arel_table
    Arel::Table.new(self.name)
  end

  def vmdb_database
    VmdbDatabase.find_by_id(self.vmdb_database_id)
  end

  def vmdb_database=(db)
    self.vmdb_database_id = db.id
  end

  def miq_worker
    return @miq_worker if defined?(@miq_worker)
    @miq_worker = MiqWorker.find_current_in_my_region.where(:sql_spid => self.spid).first
  end

  def miq_server
    return @miq_server if defined?(@miq_server)
    w = miq_worker
    @miq_server = w ? w.miq_server : MiqServer.find_started_in_my_region.where(:sql_spid => self.spid).first
  end

  def zone
    return @zone if defined?(@zone)
    @zone = miq_server && miq_server.zone
  end

  def pid
    return @pid if defined?(@pid)
    parent = miq_worker || miq_server
    @pid = parent && parent.pid
  end

  def blocked_by
    @record.blocked_by
  end

  #
  # Finders
  #

  def self.find(*args)
    connections = self.find_activity

    options = args.extract_options!

    case args.first
    when :first then connections.empty? ? nil : self.new(connections.first)
    when :last  then connections.empty? ? nil : self.new(connections.last)
    when :all   then connections.collect { |hash| self.new(hash) }
    end
  end

  def self.find_activity
    current_database = PgStatActivity.connection.current_database
    PgStatActivity.where(:datname => current_database).includes(:pg_locks)
  end

  protected

  def self.vmdb_database
    @vmdb_database ||= VmdbDatabase.my_database
  end
end
