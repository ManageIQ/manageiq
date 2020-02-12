require 'pg/dsn_parser'
require 'pg/logical_replication'
require 'active_hash'

class PglogicalSubscription < ActiveHash::Base
  include Vmdb::Logging

  fields :status, :dbname, :host, :user, :password, :port, :provider_region, :provider_region_name

  # Simple wrapper around the ActiveRecord::Base.connection method.
  #
  def self.connection
    ActiveRecord::Base.connection
  end

  # Instance wrapper method around the +connection+ singleton method.
  #
  def connection
    self.class.connection
  end

  # Alias for backwards compatability.
  class << self
    alias lookup_by_id find_by_id
  end

  # Ensure the subscription region is different than the current region, then
  # create or update the description.
  #
  # If the create or udpate fails and +reload_failover_monitor+ is set to true
  # then an evm-failover-monitor service restart will be queued.
  #
  def save!(reload_failover_monitor = true)
    assert_different_region!
    new_record? ? create_subscription : update_subscription
    super
  ensure
    EvmDatabase.restart_failover_monitor_service_queue if reload_failover_monitor
  end

  # Mostly a synonym for the save! method, but returns a boolean indicating
  # success or failure.
  #
  def save
    save!
    true
  rescue
    false
  end

  # Bulk save for a subscription list. After saving each subscription, an
  # evm-failover-monitor service restart is automatically queued.
  #
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

  # Safely delete the subscription, then delete the region, and restart
  # the evm-failover-monitor service as a queued operation if the
  # +reload_failover_monitor_service+ argument is set to true, which is
  # the default.
  #
  def delete(reload_failover_monitor_service = true)
    safe_delete
    MiqRegion.destroy_region(connection, provider_region)
    EvmDatabase.restart_failover_monitor_service_queue if reload_failover_monitor_service
  end

  # Delete a list of subscriptions, or all of them by default if the +list+
  # argument is nil. Afterwards the evm-failover-monitor service is run as
  # a queued operation.
  #
  def self.delete_all(list = nil)
    (list.nil? ? find(:all) : list)&.each { |sub| sub.delete(false) }
    EvmDatabase.restart_failover_monitor_service_queue
    nil
  end

  # Wraps the Pg::LogicalReplicationClient#disable_subscription
  # method, then checks the result state.
  #
  def disable
    pglogical.disable_subscription(id).check
  end

  # Wraps the Pg::LogicalReplicationClient#enable_subscription
  # method, then checks the result state.
  #
  def enable
    pglogical.enable_subscription(id).check
  end

  # The postgres logical replication client. Creates a new
  # PG::LogicalReplication::Client if the +refresh+ argument is set to true.
  # By default the +refresh+ argument is set to false.
  #
  def self.pglogical(refresh = false)
    @pglogical = nil if refresh
    @pglogical ||= PG::LogicalReplication::Client.new(connection.raw_connection)
  end

  # Instance method wrapper around the +pglogical+ singleton method.
  #
  def pglogical(refresh = false)
    self.class.pglogical(refresh)
  end

  # Validate the +new_connection_params+ hash using the MiqRegionRemote model.
  # The keys it looks for are password, host, port, user and dbname.
  #
  # If the params[:password] is blank it wil parse it out of the
  # subscription DSN.
  #
  def validate(new_connection_params = {})
    params = new_connection_params.symbolize_keys
    find_password if params[:password].blank?
    connection_hash = attributes.merge(params.delete_blanks)

    MiqRegionRemote.validate_connection_settings(
      connection_hash[:host],
      connection_hash[:port],
      connection_hash[:user],
      connection_hash[:password],
      connection_hash[:dbname]
    )
  end

  # Essentially a wrapper around our custom +xlog_location_diff+ method, defined
  # in the ar_dba.rb file. However, this will instead log an error and return nil
  # if the current status isn't "replicating".
  #
  def backlog
    if status != "replicating"
      _log.error("Is `#{dbname}` running on host `#{host}` and accepting TCP/IP connections on port #{port} ?")
      return nil
    end
    begin
      connection.xlog_location_diff(remote_region_lsn, remote_replication_lsn)
    rescue PG::Error => e
      _log.error(e.message)
      nil
    end
  end

  # Wrapper around the Pg::LogicalReplication::Client#sync_subscription method.
  #
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
    cols.delete(:local_replication_lsn)

    cols[:id]     = cols.delete(:subscription_name)
    cols[:status] = subscription_status(cols.delete(:worker_count), cols.delete(:enabled))

    # create the individual dsn columns
    cols.merge!(dsn_attributes(cols[:subscription_dsn]))

    cols.merge!(remote_region_attributes(cols[:id]))
  end
  private_class_method :subscription_to_columns

  # Returns a subscription status based on the number of +workers+ and whether
  # or not the subscription is +enabled+.
  #
  # If the subscription is not enabled, then the result is "disabled" no matter
  # what. Otherwise, the status is "down" if there are no workers, "replicating"
  # if there is one worker, or "initializing" if there is more than one worker.
  #
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

  # Wrapper for the Pg::LogicalReplication::Client#subscriptions method.
  # The results of that method are also assigned as the data for the
  # ActiveHash object.
  #
  def self.subscriptions
    self.data = pglogical.subscriptions(connection.current_database)
  end
  private_class_method :subscriptions

  # Takes an array of hash subscriptions, and converts them into proper
  # ActiveHash objects.
  #
  def self.data=(subscriptions)
    super(subscriptions.map{ |sub| subscription_to_columns(sub) })
  end

  private

  # Safely drop a subscription. Certain errors are ignored, i.e. if a connection
  # to the publisher cannot be made, or if the replication slot does not exist.
  # In those cases the slot name is renamed to 'NONE' and the operation is
  # retried.
  #
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

  def update
    find_password if password.blank?
    pglogical.set_subscription_conninfo(id, conn_info_hash)
    super
  end

  def update_subscription
    find_password if password.nil?
    pglogical.set_subscription_conninfo(id, conn_info_hash)
    self
  end

  # sets this instance's password field to the one in the subscription dsn in the database
  def find_password
    return password if password.present?
    dsn_hash = PG::DSNParser.parse(subscription_dsn)
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
end
