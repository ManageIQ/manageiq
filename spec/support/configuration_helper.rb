module ConfigurationHelper
  def stub_server_configuration(config, config_name = "vmdb")
    allow(VMDB::Config).to receive(:new).with(config_name).and_return(double(:config => config))
  end
end
