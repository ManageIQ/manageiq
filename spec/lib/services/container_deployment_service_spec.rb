RSpec.describe ContainerDeploymentService do
  before do
    %w(amazon openstack google azure redhat vmware).each do |p|
      network = FactoryBot.create(:network, :ipaddress => "127.0.0.1")
      hardware = FactoryBot.create(:hardware)
      hardware.networks << network
      vm = FactoryBot.create("vm_#{p}".to_sym, :hardware => hardware)
      if %w(amazon redhat).include?(p)
        template = FactoryBot.create("template_#{p}".to_sym)
        provider = FactoryBot.create("ems_#{p}".to_sym, :miq_templates => [template])
      else
        provider = FactoryBot.create("ems_#{p}".to_sym)
      end
      provider.vms << vm
    end
    @foreman_provider = FactoryBot.create(:configuration_manager_foreman)
  end

  context "possible_providers_and_vms" do
    it "finds all Cloud and Infra providers and their existing VMs" do
      providers = described_class.new.possible_providers_and_vms
      vms = providers.collect_concat { |p| p[:vms] }
      expect(providers.size).to eq(6)
      expect(vms.size).to eq(6)
    end
  end

  context "possible_provision_providers" do
    it "finds all providers with provision ability supported by deployment, and their templates" do
      providers = described_class.new.possible_provision_providers
      templates = providers.collect_concat { |p| p[:templates] }
      expect(providers.size).to eq(2)
      expect(templates.size).to eq(2)
    end
  end
end
