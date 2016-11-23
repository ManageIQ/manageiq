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

def stub_local_settings_file(path, content)
  path = path.to_s

  orig_exists_call = File.method(:exist?)
  allow(File).to receive(:exist?) do |p|
    p == path ? true : orig_exists_call.call(p)
  end

  orig_io_call = IO.method(:read)
  allow(IO).to receive(:read) do |p|
    p == path ? content : orig_io_call.call(p)
  end

  ::Settings.reload!
end

def stub_server_configuration(config, config_name = "vmdb")
  configuration = double(:config => config.deep_symbolize_keys)
  allow(VMDB::Config).to receive(:new).with(config_name) { configuration }
end
