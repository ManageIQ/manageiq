describe ManageIQ::Providers::Redhat::InfraManager::OvirtServices::Strategies::V4 do
  describe "#advertised_images" do
    let(:ems) { FactoryGirl.create(:ems_redhat_with_authentication) }
    let(:vm) { FactoryGirl.create(:vm_redhat, :ext_management_system => ems) }
    let(:ems_service) { instance_double(OvirtSDK4::Connection) }
    let(:system_service) { instance_double(OvirtSDK4::SystemService) }
    let(:data_centers_service) { instance_double(OvirtSDK4::DataCentersService) }
    let(:data_center_up) { OvirtSDK4::DataCenter.new(:status => OvirtSDK4::DataCenterStatus::UP) }
    let(:data_center_down) { OvirtSDK4::DataCenter.new(:status => OvirtSDK4::DataCenterStatus::MAINTENANCE) }
    let(:active_data_centers) { [data_center_up] }
    let(:storage_domain_list_1) { instance_double(OvirtSDK4::List) }
    let(:storage_domains) { [storage_domain_data, storage_domain_iso_down, storage_domain_iso_up] }
    let(:storage_domain_data) { OvirtSDK4::StorageDomain.new(:status => nil, :type => "data") }
    let(:storage_domain_iso_down) { OvirtSDK4::StorageDomain.new(:status => "maintenance", :type => "iso") }
    let(:storage_domain_iso_up) { OvirtSDK4::StorageDomain.new(:status => "active", :type => "iso", :id => "iso_sd_id") }
    let(:storage_domains_service) { instance_double(OvirtSDK4::StorageDomainsService) }
    let(:storage_domain_iso_up_service) { instance_double(OvirtSDK4::StorageDomainService) }
    let(:files_service) { instance_double(OvirtSDK4::FilesService) }
    let(:iso_images) { [double("iso1", :name => "iso_1"), double("iso2", :name => "iso_2")] }
    let(:query) { { :search => "status=#{OvirtSDK4::DataCenterStatus::UP}" } }

    before do
      allow(ems).to receive(:with_provider_connection).and_yield(ems_service)
      allow(ems_service).to receive(:system_service).and_return(system_service)
      allow(system_service).to receive(:data_centers_service).and_return(data_centers_service)
      allow(data_centers_service).to receive(:list).with(:query => query).and_return(active_data_centers)
      allow(data_center_up).to receive(:storage_domains).and_return(storage_domain_list_1)
      allow(ems_service).to receive(:follow_link).with(storage_domain_list_1).and_return(storage_domains)
      allow(system_service).to receive(:storage_domains_service).and_return(storage_domains_service)
      allow(storage_domains_service).to receive(:storage_domain_service).with(storage_domain_iso_up.id).and_return(storage_domain_iso_up_service)
      allow(storage_domain_iso_up_service).to receive(:files_service).and_return(files_service)
      allow(files_service).to receive(:list).and_return(iso_images)
    end

    subject(:advertised_images) do
      described_class.new(:ems => ems).advertised_images
    end

    context "there is a an active data-center" do
      context "there are iso domains attached to the data-center" do
        context "there are active iso domains" do
          it 'returns iso images from an active domain' do
            expect(advertised_images).to match_array(%w(iso_1 iso_2))
          end
        end

        context "there are no active iso domains" do
          let(:storage_domains) { [storage_domain_data, storage_domain_iso_down] }

          it 'returns an empty array' do
            expect(advertised_images).to match_array([])
          end
        end
      end

      context "there are no iso domains attached to the data-center" do
        let(:storage_domains) { [storage_domain_data] }

        it 'returns an empty array' do
          expect(advertised_images).to match_array([])
        end
      end
    end

    context "there are no active data-centers" do
      let(:active_data_centers) { [] }

      it 'returns an empty array' do
        expect(advertised_images).to match_array([])
      end
    end
  end
end
