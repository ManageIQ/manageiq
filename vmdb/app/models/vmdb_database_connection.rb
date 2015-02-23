class VmdbDatabaseConnection < ActsAsArModel
  set_columns_hash(
    :address           => :string,
    :application       => :string,
    :blocked_by        => :integer,
    :command           => :string,
    :spid              => :integer,
    :task_state        => :string,
    :wait_resource     => :string,
    :wait_time         => :integer,
    :vmdb_database_id  => :integer
  )

  virtual_belongs_to :vmdb_database
  virtual_belongs_to :zone
  virtual_belongs_to :miq_server
  virtual_belongs_to :miq_worker

  virtual_column :pid, :type => :integer

  def initialize(values = {})
    values[:vmdb_database] ||= self.class.vmdb_database
    super(values)
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

  #
  # Finders
  #

  def self.find(*args)
    connections = self.vmdb_database_connections

    options = args.extract_options!

    case args.first
    when :first then connections.empty? ? nil : self.new(connections.first)
    when :last  then connections.empty? ? nil : self.new(connections.last)
    when :all   then connections.collect { |hash| self.new(hash) }
    end
  end

  protected

  def self.vmdb_database
    @vmdb_database ||= VmdbDatabase.my_database
  end

  def self.vmdb_database_connections
    connections = PgStatActivity.activity_stats
    return [] if connections.nil?
    connections.collect { |hash| filtered_hash(hash) }
  end

  def self.filtered_hash(hash)
    dictionary = {
      :address       => 'net_address',
      :application   => 'application',
      :blocked_by    => 'blocked_by',
      :command       => 'command',
      :spid          => 'session_id',
      :task_state    => 'task_state',
      :wait_resource => 'wait_resource',
      :wait_time     => 'wait_time_ms',
    }
    filtered_hash = {}
    dictionary.each { |key, pg_key| filtered_hash[key] = hash[pg_key] }
    filtered_hash
  end

end
