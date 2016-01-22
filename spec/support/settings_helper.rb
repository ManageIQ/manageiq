def stub_settings(hash)
  stub_const("Settings", Config::Options.new.merge!(hash))
end

def stub_server_configuration(config, config_name = "vmdb")
  configuration = double(:config => config.deep_symbolize_keys)
  allow(VMDB::Config).to receive(:new).with(config_name) { configuration }
end
