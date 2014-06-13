if MiqEnvironment::Process.is_web_server_worker?
  session_options = {}
  if MiqEnvironment::Command.is_appliance?
    session_options[:secure]   = true
    session_options[:httponly] = true
  end

  # Look for the session_store and memcache_server settings in this sequence:
  # 1) the vmdb.yml.db file
  # 2) the vmdb.tmpl.yml file
  db_file  = Rails.root.join("config", "vmdb.yml.db")
  template = Rails.root.join("config", "vmdb.tmpl.yml")
  config_file = File.exists?(db_file) ? db_file : template

  config = YAML.load(File.read(config_file))
  evm_store = config.fetch_path("server", "session_store")
  rails_store = case evm_store
  when "sql";     :active_record_store
  when "memory";  :memory_store
  when "cache";   :dalli_store
  else
    raise "session_store, '#{evm_store}', invalid. Should be one of 'sql', 'memory', 'cache'"
  end

  if rails_store == :dalli_store
    require "action_dispatch/middleware/session/dalli_store"
    memcached_server = config.fetch_path("session", "memcache_server") || "127.0.0.1:11211"
    session_options = session_options.merge({
      :cache          => Dalli::Client.new(memcached_server, :namespace => "MIQ:VMDB"),
      :expires_after  => 24.hours,
      # :compress       => true,
      :key            => "_vmdb_session",
      # :readonly       => false,
      # :urlencode      => false,
      # :logger         => $log,
      # :socket_timeout => 5,
      # :failover       => false
    })
  end

  Vmdb::Application.config.session_store rails_store, session_options
  msg = "Using session_store: #{Vmdb::Application.config.session_store}"
  $log.info("MIQ(SessionStore) #{msg}")
  puts "** #{msg}" unless Rails.env.production?
end
