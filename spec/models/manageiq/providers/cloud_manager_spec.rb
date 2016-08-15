describe EmsCloud do
  it ".types" do
    expected_types = [ManageIQ::Providers::Amazon::CloudManager,
                      ManageIQ::Providers::Azure::CloudManager,
                      ManageIQ::Providers::Openstack::CloudManager,
                      ManageIQ::Providers::Google::CloudManager,
                      ManageIQ::Providers::Vmware::CloudManager].collect(&:ems_type)
    expect(described_class.types).to match_array(expected_types)
  end

  it ".supported_subclasses" do
    expected_subclasses = [ManageIQ::Providers::Amazon::CloudManager,
                           ManageIQ::Providers::Azure::CloudManager,
                           ManageIQ::Providers::Openstack::CloudManager,
                           ManageIQ::Providers::Google::CloudManager,
                           ManageIQ::Providers::Vmware::CloudManager]
    expect(described_class.supported_subclasses).to match_array(expected_subclasses)
  end

  it ".supported_types" do
    expected_types = [ManageIQ::Providers::Amazon::CloudManager,
                      ManageIQ::Providers::Azure::CloudManager,
                      ManageIQ::Providers::Openstack::CloudManager,
                      ManageIQ::Providers::Google::CloudManager,
                      ManageIQ::Providers::Vmware::CloudManager].collect(&:ems_type)
    expect(described_class.supported_types).to match_array(expected_types)
  end

  context "OpenStack CloudTenant Mapping" do
    describe "#sync_cloud_tenants_with_tenants" do
      let(:ems_cloud)       { FactoryGirl.create(:ems_openstack) }
      let!(:default_tenant) { Tenant.seed }
      let(:name_of_created_tenant) do
        "#{ManageIQ::Providers::Openstack::CloudManager.description} Cloud Provider #{ems_cloud.name}"
      end

      it "creates tenant related to provider" do
        ems_cloud.sync_cloud_tenants_with_tenants

        ems_cloud.reload

        expect(ems_cloud.source_tenant).not_to be_nil
        expect(ems_cloud.source_tenant.name).to eq(name_of_created_tenant)
        expect(ems_cloud.source_tenant.description).to eq(name_of_created_tenant)
      end

      it "creates only the one tenant per openstack provider when synchronization was executed multiple times" do
        count_of_tenants = Tenant.count

        ems_cloud.sync_cloud_tenants_with_tenants

        expect(Tenant.count).to eq(count_of_tenants + 1)
        ems_cloud.reload

        ems_cloud.sync_cloud_tenants_with_tenants

        ems_cloud.reload
        ems_cloud.sync_cloud_tenants_with_tenants

        expect(Tenant.count).to eq(count_of_tenants + 1)
      end

      it "name and description of tenant created by openstack is updated" do
        ems_cloud.sync_cloud_tenants_with_tenants

        ems_cloud.reload

        ems_cloud.source_tenant.update_attributes(:name => "XXX", :description => "XXX")
        ems_cloud.save

        ems_cloud.sync_cloud_tenants_with_tenants

        ems_cloud.reload

        expect(ems_cloud.source_tenant.name).to eq(name_of_created_tenant)
        expect(ems_cloud.source_tenant.description).to eq(name_of_created_tenant)
      end
    end
  end
end
