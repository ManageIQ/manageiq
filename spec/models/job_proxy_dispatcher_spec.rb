RSpec.describe JobProxyDispatcher do
  include Spec::Support::JobProxyDispatcherHelper

  NUM_VMS = 3
  NUM_REPO_VMS = 3
  NUM_HOSTS = 3
  NUM_SERVERS = 3
  NUM_STORAGES = 3

  let(:zone) { FactoryBot.create(:zone) }
  let(:dispatcher) do
    JobProxyDispatcher.new.tap do |dispatcher|
      dispatcher.instance_variable_set(:@zone, zone.name)
    end
  end

  before do
    @server = EvmSpecHelper.local_miq_server(:name => "test_server_main_server", :zone => zone)
  end

  context "With a default zone, server, with hosts with a miq_proxy, vmware vms on storages" do
    before do
      (NUM_SERVERS - 1).times do |i|
        FactoryBot.create(:miq_server, :zone => @server.zone, :name => "test_server_#{i}")
      end

      # TODO: We should be able to set values so we don't need to stub behavior
      allow_any_instance_of(MiqServer).to receive_messages(:is_vix_disk? => true)
      allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
      allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => true)
      allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive_messages(:missing_credentials? => false)
      allow_any_instance_of(Host).to receive_messages(:missing_credentials? => false)

      @hosts, @proxies, @storages, @vms, @repo_vms, @container_providers = build_entities(
        :hosts => NUM_HOSTS, :storages => NUM_STORAGES, :vms => NUM_VMS, :repo_vms => NUM_REPO_VMS, :zone => zone
      )
      @container_images = @container_providers.collect(&:container_images).flatten
    end
  end
end
