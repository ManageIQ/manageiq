# This model wraps a pglogical stored proc (pglogical.show_subscription_status)
# This is exposed to us through the PostgreSQLAdapter#pglogical object's #subscriptions method
# This model then exposes select values returned from that method
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

  def save!
    raise _("Cannot update an existing subscription") if id
    ensure_node_created
    pglogical.subscription_create(new_subscription_name, dsn, [MiqPglogical::REPLICATION_SET_NAME],
                                  false).check
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
        s.save!
      rescue StandardError => e
        errors << "Failed to save subscription to #{s.host}: #{e.message}"
      end
    end

    unless errors.empty?
      raise errors.join("\n")
    end
    subscription_list
  end

  def delete
    pglogical.subscription_drop(id, true)
    MiqRegion.destroy_region(connection, provider_region)
    pglogical.node_drop(MiqPglogical.local_node_name, true) if self.class.count == 0
  end

  def self.delete_all
    find(:all).each(&:delete)
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

  # translate the output from the pglogical stored proc to our object columns
  def self.subscription_to_columns(sub)
    cols = sub.symbolize_keys

    # delete the things we dont care about
    cols.delete(:slot_name)
    cols.delete(:replication_sets)
    cols.delete(:forward_origins)

    cols[:id] = cols.delete(:subscription_name)

    # create the individual dsn columns
    cols.merge!(dsn_attributes(cols.delete(:provider_dsn)))

    cols.merge!(provider_node_attributes(cols.delete(:provider_node)))
  end
  private_class_method :subscription_to_columns

  def self.dsn_attributes(dsn)
    attrs = connection.class.parse_dsn(dsn)
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

  def new_subscription_name
    MiqRegionRemote.with_remote_connection(host, port || 5432, user, decrypted_password, dbname, "postgresql") do |_conn|
      "region_#{MiqRegionRemote.region_number_from_sequence}_subscription"
    end
  end

  def ensure_node_created
    return if MiqPglogical.new.node?

    pglogical.enable
    node_dsn = PG::Connection.parse_connect_args(connection.raw_connection.conninfo_hash.delete_blanks)
    pglogical.node_create(MiqPglogical.local_node_name, node_dsn).check
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
end
