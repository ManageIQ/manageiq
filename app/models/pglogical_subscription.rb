# This model wraps a pglogical stored proc (pglogical.show_subscription_status)
# This is exposed to us through the PostgreSQLAdapter#pglogical object's #subscriptions method
# This model then exposes select values returned from that method
require 'pg/dsn_parser'
require 'pg/pglogical'
require 'pg/pglogical/active_record_extension'

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

  def self.find_by_id(to_find)
    find(to_find)
  rescue ActiveRecord::RecordNotFound
    nil
  end

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
    pglogical.subscription_drop(id, true)
    MiqRegion.destroy_region(connection, provider_region)
    if self.class.count == 0
      pglogical.node_drop(MiqPglogical.local_node_name, true)
      pglogical.disable
    end
    EvmDatabase.restart_failover_monitor_service_queue if reload_failover_monitor_service
  end

  def self.delete_all(list = nil)
    (list.nil? ? find(:all) : list)&.each { |sub| sub.delete(false) }
    EvmDatabase.restart_failover_monitor_service_queue
    nil
  end

  def disable
    pglogical.subscription_disable(id).check
  end

  def enable
    pglogical.subscription_enable(id).check
  end

  def self.pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= connection.pglogical
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
    connection.xlog_location_diff(remote_node_lsn, remote_replication_lsn)
  rescue PG::Error => e
    _log.error(e.message)
    nil
  end

  # translate the output from the pglogical stored proc to our object columns
  def self.subscription_to_columns(sub)
    cols = sub.symbolize_keys

    # delete the things we dont care about
    cols.delete(:slot_name)
    cols.delete(:replication_sets)
    cols.delete(:forward_origins)
    cols.delete(:remote_replication_lsn)
    cols.delete(:local_replication_lsn)

    cols[:id] = cols.delete(:subscription_name)

    # create the individual dsn columns
    cols.merge!(dsn_attributes(cols.delete(:provider_dsn)))

    cols.merge!(provider_node_attributes(cols.delete(:provider_node)))
  end
  private_class_method :subscription_to_columns

  def self.dsn_attributes(dsn)
    attrs = PG::DSNParser.parse(dsn)
    attrs.select! { |k, _v| [:dbname, :host, :user, :port].include?(k) }
    port = attrs.delete(:port)
    attrs[:port] = port.to_i unless port.blank?
    attrs
  end
  private_class_method :dsn_attributes

  def self.provider_node_attributes(node_name)
    attrs = {}
    attrs[:provider_region] = MiqPglogical.node_name_to_region(node_name)
    region = MiqRegion.find_by_region(attrs[:provider_region])
    attrs[:provider_region_name] = region.description if region
    attrs
  end
  private_class_method :provider_node_attributes

  def self.subscriptions
    pglogical.enabled? ? pglogical.subscriptions : []
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

  def remote_region_number
    with_remote_connection do |_conn|
      return MiqRegionRemote.region_number_from_sequence
    end
  end

  def new_subscription_name
    "region_#{remote_region_number}_subscription"
  end

  def ensure_node_created
    return if MiqPglogical.new.node?

    pglogical.enable
    node_dsn = PG::Connection.parse_connect_args(connection.raw_connection.conninfo_hash.delete_blanks)
    pglogical.node_create(MiqPglogical.local_node_name, node_dsn).check
  end

  def with_subscription_disabled
    disable
    yield
  ensure
    enable
  end

  def update_subscription
    with_subscription_disabled do
      provider_node_name = MiqPglogical.region_to_node_name(provider_region)
      find_password if password.nil?
      pglogical.node_dsn_update(provider_node_name, dsn)
    end
    self
  end

  # sets this instance's password field to the one in the subscription dsn in the database
  def find_password
    return password if password.present?
    s = pglogical.subscription_show_status(id).symbolize_keys
    dsn_hash = PG::DSNParser.parse(s.delete(:provider_dsn))
    self.password = dsn_hash[:password]
  end

  def create_subscription
    ensure_node_created
    MiqRegion.destroy_region(connection, remote_region_number)
    pglogical.subscription_create(new_subscription_name, dsn, [MiqPglogical::REPLICATION_SET_NAME],
                                  false).check
    self
  end

  def assert_different_region!
    if MiqRegionRemote.region_number_from_sequence == remote_region_number
      raise "Subscriptions cannot be created to the same region as the current region"
    end
  end

  def dsn
    conf = {
      :dbname   => dbname,
      :host     => host,
      :user     => user,
      :password => decrypted_password,
      :port     => port
    }.delete_blanks
    PG::Connection.parse_connect_args(conf)
  end

  def decrypted_password
    MiqPassword.try_decrypt(password)
  end

  def remote_replication_lsn
    pglogical.subscription_show_status(id)["remote_replication_lsn"]
  end

  def remote_node_lsn
    with_remote_connection(&:xlog_location)
  end

  def with_remote_connection
    find_password
    MiqRegionRemote.with_remote_connection(host, port || 5432, user, decrypted_password, dbname, "postgresql") do |conn|
      yield conn
    end
  end
end
