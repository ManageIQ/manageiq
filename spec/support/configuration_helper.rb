module ConfigurationHelper
  def stub_server_configuration(config, config_name = "vmdb")
    configuration = double(:config                         => config,
                           :merge_from_template_if_missing => nil,
                           :merge_from_template            => nil)
    allow(VMDB::Config).to receive(:new).with(config_name).and_return(configuration)
  end
end
