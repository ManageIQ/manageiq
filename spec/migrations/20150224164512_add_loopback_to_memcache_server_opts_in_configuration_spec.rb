require_migration

describe AddLoopbackToMemcacheServerOptsInConfiguration do
  let(:configuration_stub) { migration_stub(:Configuration) }

  migration_context :up do
    it "leaves custom memcache_server_opts" do
      custom_binding = "-l 0.0.0.0"
      with_custom = {"session" => {"memcache_server_opts" => custom_binding}}
      config = configuration_stub.create!(:typ => 'vmdb', :settings => with_custom)

      migrate

      expect(config.reload.settings.fetch_path("session", "memcache_server_opts")).to eq(custom_binding)
    end

    it "adds listen on localhost binding to memcache_server_opts" do
      default_binding = "-l 127.0.0.1"
      with_blank = {"session" => {"memcache_server_opts" => ""}}
      config = configuration_stub.create!(:typ => 'vmdb', :settings => with_blank)

      migrate

      expect(config.reload.settings.fetch_path("session", "memcache_server_opts")).to eq(default_binding)
    end
  end

  migration_context :down do
    it "leaves custom memcache_server_opts" do
      custom_binding = "-l 0.0.0.0"
      with_custom = {"session" => {"memcache_server_opts" => custom_binding}}
      config = configuration_stub.create!(:typ => 'vmdb', :settings => with_custom)

      migrate

      expect(config.reload.settings.fetch_path("session", "memcache_server_opts")).to eq(custom_binding)
    end

    it "reverts listen on localhost binding to blank option" do
      default_binding = "-l 127.0.0.1"
      with_blank = {"session" => {"memcache_server_opts" => default_binding}}
      config = configuration_stub.create!(:typ => 'vmdb', :settings => with_blank)

      migrate

      expect(config.reload.settings.fetch_path("session", "memcache_server_opts")).to eq("")
    end
  end
end
