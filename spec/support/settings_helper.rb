def stub_settings(hash)
  settings = Config::Options.new.merge!(hash)
  stub_const("Settings", settings)
  allow(Vmdb::Settings).to receive(:for_resource) { settings }
end

def stub_template_settings(hash)
  settings = Config::Options.new.merge!(hash)
  allow(Vmdb::Settings).to receive(:template_settings) { settings }
end

def stub_local_settings(my_server)
  stub_const("Settings", Vmdb::Settings.for_resource(my_server))
end

def stub_server_configuration(config, config_name = "vmdb")
  configuration = double(:config => config.deep_symbolize_keys)
  allow(VMDB::Config).to receive(:new).with(config_name) { configuration }
end
