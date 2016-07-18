require 'recursive-open-struct'

describe ContainerDeploymentService do
  before do
    %w(amazon openstack google azure redhat vmware).each do |p|
      network = FactoryGirl.create(:network, :ipaddress => "127.0.0.1")
      hardware = FactoryGirl.create(:hardware)
      hardware.networks << network
      vm = FactoryGirl.create("vm_#{p}".to_sym, :hardware => hardware)
      if %w(amazon redhat).include?(p)
        template = FactoryGirl.create("template_#{p}".to_sym)
        provider = FactoryGirl.create("ems_#{p}".to_sym, :miq_templates => [template])
      else
        provider = FactoryGirl.create("ems_#{p}".to_sym)
      end
      provider.vms << vm
    end
    @foreman_provider = FactoryGirl.create(:configuration_manager_foreman)
  end

  context "possible_providers_and_vms" do
    it "finds all Cloud and Infra providers and their existing VMs" do
      providers = ContainerDeploymentService.new.possible_providers_and_vms
      vms = providers.collect_concat { |p| p[:vms] }
      expect(providers.size).to eq(6)
      expect(vms.size).to eq(6)
    end
  end

  context "possible_provision_providers" do
    it "finds all providers with provision ability supported by deployment, and their templates" do
      providers = ContainerDeploymentService.new.possible_provision_providers
      templates = providers.collect_concat { |p| p[:templates] }
      expect(providers.size).to eq(2)
      expect(templates.size).to eq(2)
    end
  end
end
