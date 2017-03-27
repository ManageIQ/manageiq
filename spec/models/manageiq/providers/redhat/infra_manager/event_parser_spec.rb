describe ManageIQ::Providers::Redhat::InfraManager::EventParser  do
  context 'parse event using v3' do
    let(:ip_address) { '192.168.1.105' }

    before(:each) do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => ip_address, :ipaddress => ip_address,
                                :port => 8443)
      @ems.update_authentication(:default => {:userid => "admin@internal", :password => "engine"})

      allow(@ems).to receive(:supported_api_versions).and_return([3])
      allow(@ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)
    end

    it "should parse event" do
      event = {:id=>"414",
               :href=>"/ovirt-engine/api/events/414",
               :cluster=>{:id=>"00000002-0002-0002-0002-00000000017a",
                          :href=>"/ovirt-engine/api/clusters/00000002-0002-0002-0002-00000000017a"},
               :data_center=>{:id=>"00000001-0001-0001-0001-000000000311",
                              :href=>"/ovirt-engine/api/datacenters/00000001-0001-0001-0001-000000000311"},
               :user=>{:id=>"58ad9d2d-013a-00aa-018f-00000000022e",
                       :href=>"/ovirt-engine/api/users/58ad9d2d-013a-00aa-018f-00000000022e"},
               :vm=>{:id=>"3a697bd0-7cea-42a1-95ef-fd292fcee721",
                     :href=>"/ovirt-engine/api/vms/3a697bd0-7cea-42a1-95ef-fd292fcee721"},
               :description=>"VM new configuration was updated by admin@internal-authz.",
               :severity=>"normal",
               :code=>35,
               :time=>"2017-02-27 15:44:20 +0100",
               :name=>"USER_UPDATE_VM"}
      allow(ManageIQ::Providers::Redhat::InfraManager).to receive(:find_by).with(:id => @ems.id).and_return(@ems)

      VCR.use_cassette("#{described_class.name.underscore}_parse_event", :allow_unused_http_interactions => true, :allow_playback_repeats => true, :record => :new_episodes) do
        parsed = ManageIQ::Providers::Redhat::InfraManager::EventParser.event_to_hash(event, @ems.id)

        expect(parsed).to have_attributes(
          :event_type          => "USER_UPDATE_VM",
          :source              => 'RHEVM',
          :message             => "VM new configuration was updated by admin@internal-authz.",
          :timestamp           => "2017-02-27 15:44:20 +0100",
          :username            => "admin@internal-authz",
          :full_data           => event,
          :ems_id              => @ems.id,
        )
      end
    end
  end
end