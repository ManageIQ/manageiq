describe ManageIQ::Providers::Redhat::InfraManager::EventParser do
  context 'parse event using v3' do
    let(:ip_address) { '192.168.1.105' }

    before(:each) do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => ip_address, :ipaddress => ip_address,
                                :port => 8443)
      @ems.update_authentication(:default => {:userid => "admin@internal", :password => "engine"})
      @ems.default_endpoint.verify_ssl = OpenSSL::SSL::VERIFY_NONE
      allow(@ems).to receive(:supported_api_versions).and_return([3])
      allow(@ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)
    end

    it "should parse event" do
      event = {:id          => "414",
               :href        => "/ovirt-engine/api/events/414",
               :cluster     => {:id   => "00000002-0002-0002-0002-00000000017a",
                                :href => "/ovirt-engine/api/clusters/00000002-0002-0002-0002-00000000017a"},
               :data_center => {:id   => "00000001-0001-0001-0001-000000000311",
                                :href => "/ovirt-engine/api/datacenters/00000001-0001-0001-0001-000000000311"},
               :user        => {:id   => "58ad9d2d-013a-00aa-018f-00000000022e",
                                :href => "/ovirt-engine/api/users/58ad9d2d-013a-00aa-018f-00000000022e"},
               :vm          => {:id   => "3a697bd0-7cea-42a1-95ef-fd292fcee721",
                                :href => "/ovirt-engine/api/vms/3a697bd0-7cea-42a1-95ef-fd292fcee721"},
               :description => "VM new configuration was updated by admin@internal-authz.",
               :severity    => "normal",
               :code        => 35,
               :time        => "2017-02-27 15:44:20 +0100",
               :name        => "USER_UPDATE_VM"}
      allow(ManageIQ::Providers::Redhat::InfraManager).to receive(:find_by).with(:id => @ems.id).and_return(@ems)

      VCR.use_cassette("#{described_class.name.underscore}_parse_event", :allow_unused_http_interactions => true, :allow_playback_repeats => true, :record => :new_episodes) do
        parser = ManageIQ::Providers::Redhat::InfraManager::EventParsing::Builder.new(@ems).build
        parsed = parser.event_to_hash(event, @ems.id)
        expect(parsed).to have_attributes(
          :event_type => "USER_UPDATE_VM",
          :source     => 'RHEVM',
          :message    => "VM new configuration was updated by admin@internal-authz.",
          :timestamp  => "2017-02-27 15:44:20 +0100",
          :username   => "admin@internal-authz",
          :full_data  => event,
          :ems_id     => @ems.id,
        )
      end
    end

    it "should parse new target" do
      allow(@ems.ovirt_services).to receive(:cluster_name_href).and_return("Default")
      event = {:id          => "661",
               :href        => "/ovirt-engine/api/events/661",
               :cluster     => {:id   => "00000002-0002-0002-0002-00000000017a",
                                :href => "/ovirt-engine/api/clusters/00000002-0002-0002-0002-00000000017a"},
               :data_center => {:id   => "00000001-0001-0001-0001-000000000311",
                                :href => "/ovirt-engine/api/datacenters/00000001-0001-0001-0001-000000000311"},
               :template    => {:id   => "6160a62c-a43f-4ffc-896b-93d98f55e9ef",
                                :href => "/ovirt-engine/api/templates/6160a62c-a43f-4ffc-896b-93d98f55e9ef"},
               :user        => {:id   => "58d90d4c-00cb-00bf-03bd-000000000320",
                                :href => "/ovirt-engine/api/users/58d90d4c-00cb-00bf-03bd-000000000320"},
               :vm          => {:id   => "22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                :href => "/ovirt-engine/api/vms/22f18a6b-fc44-43ae-976f-993ad5f1d648"},
               :description => "Network Interface nic1 (VirtIO) was plugged to VM test2. (User: admin@internal-authz)",
               :severity    => "normal",
               :code        => 1012,
               :time        => "2017-04-19 12:55:38 +0200",
               :name        => "NETWORK_INTERFACE_PLUGGED_INTO_VM"}

      event2 = {:id          => "662",
                :href        => "/ovirt-engine/api/events/662",
                :cluster     => {:id   => "00000002-0002-0002-0002-00000000017a",
                                 :href => "/ovirt-engine/api/clusters/00000002-0002-0002-0002-00000000017a"},
                :data_center => {:id   => "00000001-0001-0001-0001-000000000311",
                                 :href => "/ovirt-engine/api/datacenters/00000001-0001-0001-0001-000000000311"},
                :template    => {:id   => "6160a62c-a43f-4ffc-896b-93d98f55e9ef",
                                 :href => "/ovirt-engine/api/templates/6160a62c-a43f-4ffc-896b-93d98f55e9ef"},
                :user        => {:id   => "58d90d4c-00cb-00bf-03bd-000000000320",
                                 :href => "/ovirt-engine/api/users/58d90d4c-00cb-00bf-03bd-000000000320"},
                :vm          => {:id   => "22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                 :href => "/ovirt-engine/api/vms/22f18a6b-fc44-43ae-976f-993ad5f1d648"},
                :description => "Interface nic1 (VirtIO) was added to VM test2. (User: admin@internal-authz)",
                :severity    => "normal",
                :code        => 932,
                :time        => "2017-04-19 12:55:38 +0200",
                :name        => "NETWORK_ADD_VM_INTERFACE"}

      event3 = {:id          => "668",
                :href        => "/ovirt-engine/api/events/668",
                :cluster     => {:id   => "00000002-0002-0002-0002-00000000017a",
                                 :href => "/ovirt-engine/api/clusters/00000002-0002-0002-0002-00000000017a"},
                :data_center => {:id   => "00000001-0001-0001-0001-000000000311",
                                 :href => "/ovirt-engine/api/datacenters/00000001-0001-0001-0001-000000000311"},
                :template    => {:id   => "6160a62c-a43f-4ffc-896b-93d98f55e9ef",
                                 :href => "/ovirt-engine/api/templates/6160a62c-a43f-4ffc-896b-93d98f55e9ef"},
                :user        => {:id   => "58d90d4c-00cb-00bf-03bd-000000000320",
                                 :href => "/ovirt-engine/api/users/58d90d4c-00cb-00bf-03bd-000000000320"},
                :vm          => {:id   => "22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                 :href => "/ovirt-engine/api/vms/22f18a6b-fc44-43ae-976f-993ad5f1d648"},
                :description => "VM test2 creation has been completed.",
                :severity    => "normal",
                :code        => 53,
                :time        => "2017-04-19 12:55:52 +0200",
                :name        => "USER_ADD_VM_FINISHED_SUCCESS"}
      [event, event2, event3].each do |ev|
        VCR.use_cassette("#{described_class.name.underscore}_parse_new_target") do
          parsed = ManageIQ::Providers::Redhat::InfraManager::EventParser.parse_new_target(ev, ev[:description], @ems, ev[:name])

          expect(parsed).to have_attributes(
            :ems_id         => @ems.id,
            :vm             => {:type        => "ManageIQ::Providers::Redhat::InfraManager::Vm",
                                :ems_ref     => "/api/vms/22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                :ems_ref_obj => "/api/vms/22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                :uid_ems     => "22f18a6b-fc44-43ae-976f-993ad5f1d648",
                                :vendor      => "redhat",
                                :name        => "test2",
                                :location    => "22f18a6b-fc44-43ae-976f-993ad5f1d648.ovf",
                                :template    => false},
            :cluster        => {:ems_ref     => "/api/clusters/00000002-0002-0002-0002-00000000017a",
                                :ems_ref_obj => "/api/clusters/00000002-0002-0002-0002-00000000017a",
                                :uid_ems     => "00000002-0002-0002-0002-00000000017a",
                                :name        => "Default"},
            :resource_pools => {:name       => "Default for Cluster Default",
                                :uid_ems    => "00000002-0002-0002-0002-00000000017a_respool",
                                :is_default => true},
            :folders        => {:ems_ref => "/api/datacenters/00000001-0001-0001-0001-000000000311"}
          )
        end
      end
    end
  end

  context 'parse event using v4' do
    let(:ip_address) { '192.168.1.105' }

    before(:each) do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_redhat, :zone => zone, :hostname => "192.168.1.105", :ipaddress => "192.168.1.105",
                                :port => 8443)
      @ems.update_authentication(:default => {:userid => "admin@internal", :password => "engine"})
      @ems.default_endpoint.path = "/ovirt-engine/api"
      allow(@ems).to receive(:supported_api_versions).and_return([3, 4])
      allow(@ems).to receive(:resolve_ip_address).with(ip_address).and_return(ip_address)
    end

    require 'yaml'
    def load_response_mock_for(filename)
      prefix = described_class.name.underscore
      YAML.load_file(File.join('spec', 'models', prefix, 'response_yamls', filename + '.yml'))
    end

    before(:each) do
      inventory_wrapper_class = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies::V4
      stub_settings_merge(:ems => { :ems_redhat => { :use_ovirt_engine_sdk => true } })
      user_mock = load_response_mock_for('user')
      allow_any_instance_of(inventory_wrapper_class)
        .to receive(:username_by_href).and_return("#{user_mock.name}@#{user_mock.domain.name}")
      allow_any_instance_of(inventory_wrapper_class).to receive(:api).and_return("4.2.0_master")
      allow_any_instance_of(inventory_wrapper_class).to receive(:service)
        .and_return(OpenStruct.new(:version_string => '4.2.0_master'))
    end

    it "should parse event" do
      event_xml =
        '<event href="/ovirt-engine/api/events/16359" id="16359">
<description>VM new_vm configuration was updated by admin@internal-authz.</description>
<code>35</code>
<correlation_id>4e787afc-ed42-4193-82a0-66943860d142</correlation_id>
<custom_id>-1</custom_id>
<flood_rate>30</flood_rate>
<origin>oVirt</origin>
<severity>normal</severity>
<time>2017-05-07T15:45:05.485+03:00</time>
<cluster href="/ovirt-engine/api/clusters/504ae500-3476-450e-8243-f6df0f7f7acf" id="504ae500-3476-450e-8243-f6df0f7f7acf"/>
<data_center href="/ovirt-engine/api/datacenters/b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1" id="b60b3daa-dcbd-40c9-8d09-3fc08c91f5d1"/>
<template href="/ovirt-engine/api/templates/785e845e-baa0-4812-8a8c-467f37ad6c79" id="785e845e-baa0-4812-8a8c-467f37ad6c79"/>
<user href="/ovirt-engine/api/users/0000002c-002c-002c-002c-000000000149" id="0000002c-002c-002c-002c-000000000149"/>
<vm href="/ovirt-engine/api/vms/78e60d40-1fd9-42e7-aa07-4ef4439b5289" id="78e60d40-1fd9-42e7-aa07-4ef4439b5289"/>
</event>'

      event = OvirtSDK4::Reader.read(event_xml)
      allow(ManageIQ::Providers::Redhat::InfraManager).to receive(:find_by).with(:id => @ems.id).and_return(@ems)
      parser = ManageIQ::Providers::Redhat::InfraManager::EventParsing::Builder.new(@ems).build
      ManageIQ::Providers::Redhat::InfraManager::EventFetcher.new(@ems).set_event_name!(event)
      parsed = parser.event_to_hash(event, @ems.id)
      expect(parsed).to have_attributes(
        :event_type => "USER_UPDATE_VM",
        :source     => 'RHEVM',
        :message    => "VM new_vm configuration was updated by admin@internal-authz.",
        :timestamp  => "2017-05-07T15:45:05.485+03:00",
        :username   => "admin@internal-authz",
        :full_data  => event,
        :ems_id     => @ems.id,
      )
    end
  end
end
