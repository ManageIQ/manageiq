class AddLoopbackToMemcacheServerOptsInConfiguration < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    serialize :settings, Hash
  end

  def up
    default_binding_address = "-l 127.0.0.1"
    Configuration.where(:typ => "vmdb").each do |config|
      options = config.settings.fetch_path("session", "memcache_server_opts")
      next if options.present?

      config.settings.store_path("session", "memcache_server_opts", default_binding_address)
      config.save
    end
  end

  def down
    default_binding_address = "-l 127.0.0.1"
    Configuration.where(:typ => "vmdb").each do |config|
      options = config.settings.fetch_path("session", "memcache_server_opts")
      next unless options == default_binding_address

      config.settings.store_path("session", "memcache_server_opts", "")
      config.save
    end
  end
end
