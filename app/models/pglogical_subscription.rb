require 'pg/dsn_parser'
require 'pg/logical_replication'

class PglogicalSubscription < ActsAsArModel
  set_columns_hash(
    :id                   => :string,
    :status               => :string,
    :dbname               => :string,
    :host                 => :string,
    :user                 => :string,
    :password             => :string,
    :port                 => :integer,
    :provider_region      => :integer,
    :provider_region_name => :string
  )

  def self.find(*args)
    case args.first
    when :all then find_all
    when :first, :last then find_one(args.first)
    else find_id(args.first)
    end
  end

  def self.lookup_by_id(to_find)
    find(to_find)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  singleton_class.send(:alias_method, :find_by_id, :lookup_by_id)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_id => :lookup_by_id)

  def save!(reload_failover_monitor = true)
    assert_different_region!
    id ? update_subscription : create_subscription
  ensure
    EvmDatabase.restart_failover_monitor_service_queue if reload_failover_monitor
  end

  def save
    save!
    true
  rescue
    false
  end

  def self.save_all!(subscription_list)
    errors = []
    subscription_list.each do |s|
      begin
        s.save!(false)
      rescue => e
        errors << "Failed to save subscription to #{s.host}: #{e.message}"
      end
    end

    EvmDatabase.restart_failover_monitor_service_queue

    unless errors.empty?
      raise errors.join("\n")
    end
    subscription_list
  end

  def delete(reload_failover_monitor_service = true)
    safe_delete
    MiqRegion.destroy_region(connection, provider_region)
    EvmDatabase.restart_failover_monitor_service_queue if reload_failover_monitor_service
  end

  def self.delete_all(list = nil)
    (list.nil? ? find(:all) : list)&.each { |sub| sub.delete(false) }
    EvmDatabase.restart_failover_monitor_service_queue
    nil
  end

  def disable
    pglogical.disable_subscription(id).check
  end

  def enable
    pglogical.enable_subscription(id).check
  end

  def self.pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= PG::LogicalReplication::Client.new(connection.raw_connection)
  end

  def pglogical(refresh = false)
    self.class.pglogical(refresh)
  end

  def validate(new_connection_params = {})
    find_password if new_connection_params['password'].blank?
    connection_hash = attributes.merge(new_connection_params.delete_blanks)
    MiqRegionRemote.validate_connection_settings(connection_hash['host'],
                                                 connection_hash['port'],
                                                 connection_hash['user'],
                                                 connection_hash['password'],
                                                 connection_hash['dbname'])
  end

  def backlog
    if status != "replicating"
      _log.error("Is `#{dbname}` running on host `#{host}` and accepting TCP/IP connections on port #{port} ?")
      return nil
    end
    begin
      connection.xlog_location_diff(remote_region_lsn, subscription_attributes["remote_replication_lsn"])
    rescue PG::Error => e
      _log.error(e.message)
      nil
    end
  end

  def sync_tables
    pglogical.sync_subscription(id)
  end

  # translate the output from the pglogical stored proc to our object columns
  def self.subscription_to_columns(sub)
    cols = sub.symbolize_keys

    # delete the things we dont care about
    cols.delete(:database_name)
    cols.delete(:owner)
    cols.delete(:slot_name)
    cols.delete(:publications)
    cols.delete(:remote_replication_lsn)
    cols.delete(:local_replication_lsn)

    cols[:id]     = cols.delete(:subscription_name)
    cols[:status] = subscription_status(cols.delete(:worker_count), cols.delete(:enabled))

    # create the individual dsn columns
    cols.merge!(dsn_attributes(cols.delete(:subscription_dsn)))

    cols.merge!(remote_region_attributes(cols[:id]))
  end
  private_class_method :subscription_to_columns

  def self.subscription_status(workers, enabled)
    return "disabled" unless enabled

    case workers
    when 0
      "down"
    when 1
      "replicating"
    else
      "initializing"
    end
  end
  private_class_method :subscription_status

  def self.dsn_attributes(dsn)
    attrs = PG::DSNParser.parse(dsn)
    attrs.select! { |k, _v| [:dbname, :host, :user, :port].include?(k) }
    port = attrs.delete(:port)
    attrs[:port] = port.to_i unless port.blank?
    attrs
  end
  private_class_method :dsn_attributes

  def self.remote_region_attributes(subscription_name)
    attrs = {}
    attrs[:provider_region] = subscription_name.split("_")[1].to_i
    region = MiqRegion.find_by_region(attrs[:provider_region])
    attrs[:provider_region_name] = region.description if region
    attrs
  end
  private_class_method :remote_region_attributes

  def self.subscriptions
    pglogical.subscriptions(connection.current_database)
  end
  private_class_method :subscriptions

  def self.find_all
    subscriptions.collect { |s| new(subscription_to_columns(s)) }
  end
  private_class_method :find_all

  def self.find_one(which)
    s = subscriptions.send(which)
    new(subscription_to_columns(s)) if s
  end
  private_class_method :find_one

  def self.find_id(to_find)
    subscriptions.each do |s|
      return new(subscription_to_columns(s)) if s.symbolize_keys[:subscription_name] == to_find
    end
    raise ActiveRecord::RecordNotFound, "Coundn't find subscription with id #{to_find}"
  end
  private_class_method :find_id

  private

  def safe_delete
    pglogical.drop_subscription(id, true)
  rescue PG::InternalError => e
    raise unless e.message =~ /could not connect to publisher/ || e.message =~ /replication slot .* does not exist/
    connection.transaction do
      disable
      pglogical.alter_subscription_options(id, "slot_name" => "NONE")
      pglogical.drop_subscription(id, true)
    end
  end

  def remote_region_number
    with_remote_connection do |_conn|
      return MiqRegionRemote.region_number_from_sequence
    end
  end

  def new_subscription_name
    "region_#{remote_region_number}_subscription"
  end

  def update_subscription
    find_password if password.nil?
    pglogical.set_subscription_conninfo(id, conn_info_hash)
    self
  end

  # sets this instance's password field to the one in the subscription dsn in the database
  def find_password
    return password if password.present?
    s = subscription_attributes.symbolize_keys
    dsn_hash = PG::DSNParser.parse(s.delete(:subscription_dsn))
    self.password = dsn_hash[:password]
  end

  def create_subscription
    MiqRegion.destroy_region(connection, remote_region_number)
    pglogical.create_subscription(new_subscription_name, conn_info_hash, [MiqPglogical::PUBLICATION_NAME]).check
    self
  end

  def assert_different_region!
    if MiqRegionRemote.region_number_from_sequence == remote_region_number
      raise "Subscriptions cannot be created to the same region as the current region"
    end
  end

  def conn_info_hash
    {
      :dbname   => dbname,
      :host     => host,
      :user     => user,
      :password => decrypted_password,
      :port     => port
    }.delete_blanks
  end

  def decrypted_password
    ManageIQ::Password.try_decrypt(password)
  end

  def remote_region_lsn
    with_remote_connection(5.seconds) { |conn| conn.xlog_location }
  end

  def with_remote_connection(connect_timeout = 0)
    find_password
    MiqRegionRemote.with_remote_connection(host, port || 5432, user, decrypted_password, dbname, "postgresql", connect_timeout) do |conn|
      yield conn
    end
  end

  def subscription_attributes
    pglogical.subscriptions.find { |s| s["subscription_name"] == id }
  end
end
