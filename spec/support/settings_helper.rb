def stub_settings(hash)
  stub_const("Settings", Config::Options.new.merge!(hash))
end

def stub_server_configuration(config, config_name = "vmdb")
  configuration = double(:config                         => config,
                         :merge_from_template_if_missing => nil,
                         :merge_from_template            => nil)
  allow(configuration).to receive(:fetch_with_fallback) { |*args| config.fetch_path(args) }
  allow(VMDB::Config).to receive(:new).with(config_name) { configuration }
end
