def stub_settings(hash)
  settings = Config::Options.new.merge!(hash)
  stub_const("Settings", settings)
  allow(Vmdb::Settings).to receive(:for_resource) { settings }
end

def stub_server_configuration(config, config_name = "vmdb")
  configuration = double(:config => config.deep_symbolize_keys)
  allow(VMDB::Config).to receive(:new).with(config_name) { configuration }
end
