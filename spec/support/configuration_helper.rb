module ConfigurationHelper
  def stub_server_configuration(config)
    allow(VMDB::Config).to receive(:new).with("vmdb").and_return(double(:config => config))
  end
end
