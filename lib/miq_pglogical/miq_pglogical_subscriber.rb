class MiqPglogicalSubscriber < MiqPglogical
  def configure_subscriber
    pglogical.enable
    create_node
    refresh_subscriptions
  end

  # Lists the subscriptions in the replication configuration
  # @return Array<Hash<Symbol, String>> the list of provider database connection information
  #   This hash should contain the keys:
  #     :dbname, :user, :password, :host, :port
  def configured_subscriptions
    MiqServer.my_server.get_config.config.fetch_path(*SETTINGS_PATH, :subscriptions)
  end

  def refresh_subscriptions
    added_subscription_conf.each { |conf| create_subscription(conf) }
    removed_subscription_names.each { |name| pglogical.subscription_drop(name) }
  end

  private

  def create_subscription(conf)
    name = "subscription_#{conf[:host].gsub(/\.|-/, "_")}"
    pglogical.subscription_create(name, dsn_from_conf_hash(conf), [REPLICATION_SET_NAME], false)
  end

  def added_subscription_conf
    configured   = configured_subscriptions
    active_names = pglogical.subscriptions.collect { |s| s["subscription_name"] }
    new_conf = []
    configured.each do |config|
      if config[:name].nil? || !active_names.include?(config[:name])
        new_conf << config
      end
    end
    new_conf
  end

  def removed_subscription_names
    configured_names = configured_subscriptions.collect { |s| s[:name] }
    active_names     = pglogical.subscriptions.collect { |s| s["subscription_name"] }
    removed_names = []
    active_names.each do |name|
      removed_names << name unless configured_names.include?(name)
    end
    removed_names
  end

  def dsn_from_conf_hash(db_conn_conf)
    dsn = "dbname=#{db_conn_conf[:dbname]} host=#{db_conn_conf[:host]}"
    dsn << " user=#{db_conn_conf[:user]}" if db_conn_conf[:user]
    dsn << " password=#{db_conn_conf[:password]}" if db_conn_conf[:password]
    dsn << " port=#{db_conn_conf[:port]}" if db_conn_conf[:port]
    dsn
  end
end
