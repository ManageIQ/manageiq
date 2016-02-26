class MiqPglogicalSubscriber < MiqPglogical
  def configure_subscriber
    return if subscriber?
    pglogical.enable
    create_node
    refresh_subscriptions
  end

  def destroy_subscriber
    active_subscription_names.each { |name| pglogical.subscription_drop(name) }
    c = MiqServer.my_server.get_config
    c.store_path(*SETTINGS_PATH, :subscriptions, [])
    c.save
    drop_node
  end

  # Lists the subscriptions in the replication configuration
  # @return Array<Hash<Symbol, String>> the list of provider database connection information
  #   This hash should contain the keys:
  #     :dbname, :user, :password, :host, :port
  def configured_subscriptions
    name_configured_subscriptions
    MiqServer.my_server.get_config.config.fetch_path(*SETTINGS_PATH, :subscriptions) || []
  end

  def refresh_subscriptions
    added_subscription_conf.each { |conf| create_subscription(conf) }
    removed_subscription_names.each { |name| pglogical.subscription_drop(name) }
  end

  private

  def name_configured_subscriptions
    c = MiqServer.my_server.get_config
    return unless (subscriptions = c.config.fetch_path(*SETTINGS_PATH, :subscriptions))
    subscriptions.each do |s|
      next if s[:name]
      s[:name] = "subscription_#{s[:host].gsub(/\.|-/, "_")}"
    end
    c.config.store_path(*SETTINGS_PATH, :subscriptions, subscriptions)
    c.save
  end

  def create_subscription(conf)
    pglogical.subscription_create(conf[:name], dsn_from_conf_hash(conf), [REPLICATION_SET_NAME], false)
  end

  def added_subscription_conf
    configured   = configured_subscriptions
    active_names = active_subscription_names
    configured.each_with_object([]) do |config, new_conf|
      new_conf << config unless active_names.include?(config[:name])
    end
  end

  def removed_subscription_names
    configured_names = configured_subscriptions.collect { |s| s[:name] }
    active_names     = active_subscription_names
    active_names.each_with_object([]) do |name, removed_names|
      removed_names << name unless configured_names.include?(name)
    end
  end

  def active_subscription_names
    pglogical.subscriptions.collect { |s| s["subscription_name"] }
  end

  def dsn_from_conf_hash(db_conn_conf)
    dsn = "dbname=#{db_conn_conf[:dbname]} host=#{db_conn_conf[:host]}"
    dsn << " user=#{db_conn_conf[:user]}" if db_conn_conf[:user]
    dsn << " password=#{db_conn_conf[:password]}" if db_conn_conf[:password]
    dsn << " port=#{db_conn_conf[:port]}" if db_conn_conf[:port]
    dsn
  end
end
