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
    let(:ems_cloud) { FactoryGirl.create(:ems_openstack, :tenant_mapping_enabled => true) }
    let(:ems_infra) { FactoryGirl.create(:ext_management_system) }

    describe "#supports_cloud_tenant_mapping" do
      it "supports tenant mapping if the provider has CloudTenant relation and mapping is enabled" do
        expect(ems_cloud.supports_cloud_tenant_mapping?).to be_truthy
      end

      it "doesn't supports tenant mapping if the provider has CloudTenant relation and mapping is disabled" do
        ems_cloud.tenant_mapping_enabled = false
        expect(ems_cloud.supports_cloud_tenant_mapping?).to be_falsey
      end

      it "doesn't supports tenant mapping if the provider has not CloudTenant relation" do
        expect(ems_infra.supports_cloud_tenant_mapping?).to be_falsey
      end
    end

    describe "#sync_cloud_tenants_with_tenants" do
      let!(:default_tenant) { Tenant.seed }
      let(:name_of_created_tenant) do
        "#{ManageIQ::Providers::Openstack::CloudManager.description} Cloud Provider #{ems_cloud.name}"
      end

      context "provider is not created under root tenant" do
        let(:tenant) { FactoryGirl.build(:tenant, :parent => default_tenant) }
        let(:ems_cloud_without_root_tenant) do
          FactoryGirl.create(:ems_openstack, :tenant => tenant, :tenant_mapping_enabled => true)
        end

        it "creates provider's tenant under tenant of provider" do
          ems_cloud_without_root_tenant.sync_cloud_tenants_with_tenants

          ems_cloud_without_root_tenant.reload

          expect(ems_cloud_without_root_tenant.source_tenant.parent).not_to be_nil
          expect(ems_cloud_without_root_tenant.source_tenant.parent).not_to eq(default_tenant)
          expect(ems_cloud_without_root_tenant.source_tenant.parent).to eq(tenant)
        end
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

      context "creation of tenant tree " do
        subject! do
          ems_cloud.sync_root_tenant
          ems_cloud.reload
        end

        let(:vm_1) { FactoryGirl.create(:vm_openstack) }
        let(:vm_2) { FactoryGirl.create(:vm_openstack) }
        let(:vm_3) { FactoryGirl.create(:vm_openstack) }
        let(:vm_4) { FactoryGirl.create(:vm_openstack) }

        let!(:ct_1) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud)
        end

        let!(:ct_2) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_1,
                                                      :vms_and_templates => [vm_1, vm_2])
        end

        let!(:ct_3) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_2)
        end

        let!(:ct_4) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_2,
                                                      :vms_and_templates => [vm_3, vm_4])
        end

        def tenant_by(cloud_tenant)
          Tenant.find_by(:name => cloud_tenant.name)
        end

        let(:tenant_ct_1) { tenant_by(ct_1) }
        let(:tenant_ct_2) { tenant_by(ct_2) }
        let(:tenant_ct_3) { tenant_by(ct_3) }
        let(:tenant_ct_4) { tenant_by(ct_4) }

        let(:tenant_names) do
          [tenant_ct_1.name, tenant_ct_2.name, tenant_ct_3.name, tenant_ct_4.name]
        end

        let(:tenant_descriptions) do
          [tenant_ct_1.description, tenant_ct_2.description, tenant_ct_3.description, tenant_ct_4.description]
        end

        let(:tenant_parent_names) do
          [tenant_ct_1.parent.name, tenant_ct_2.parent.name, tenant_ct_3.parent.name, tenant_ct_4.parent.name]
        end

        def expect_tenant_names
          expect(tenant_names).to eq([ct_1.name, ct_2.name, ct_3.name, ct_4.name])
        end

        def expect_tenant_descriptions
          expect(tenant_descriptions).to eq([ct_1.description, ct_2.description, ct_3.description, ct_4.description])
        end

        def expect_tenant_parent_names
          expect(tenant_parent_names).to eq([name_of_created_tenant, ct_1.name, ct_2.name, ct_2.name])
        end

        def expect_assigned_vms
          expect(tenant_ct_2.vm_or_templates).to match_array([vm_1, vm_2])
          expect(tenant_ct_4.vm_or_templates).to match_array([vm_3, vm_4])
        end

        def expect_created_tenant_tree
          expect_tenant_names

          expect_tenant_descriptions

          expect_tenant_parent_names

          expect_assigned_vms
        end

        it "creates tenant tree from cloud tenants with VMs" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree
        end

        let(:vm_5) { FactoryGirl.create(:vm_openstack) }

        let(:ct_5) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_4,
                                                      :vms_and_templates => [vm_5])
        end

        let(:tenant_ct_5) { tenant_by(ct_5) }

        it "adds new tenant to tenant tree(new cloud tenant added)" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree

          ct_5
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree

          expect(tenant_ct_5.name).to eq(ct_5.name)
          expect(tenant_ct_5.parent.name).to eq(ct_4.name)
          expect(tenant_ct_5.vm_or_templates).to match_array([vm_5])
        end

        it "update existing tenant according to updated cloud tenant" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree

          ct_4.name = "New name"
          ct_4.description = "New description"
          ct_4.vms_and_templates << vm_5
          ct_4.save

          ems_cloud.sync_cloud_tenants_with_tenants
          tenant_ct_4.reload

          expect(tenant_ct_4.name).to eq(ct_4.name)
          expect(tenant_ct_4.description).to eq(ct_4.description)
          expect(tenant_ct_4.parent.name).to eq(ct_2.name)
          expect(tenant_ct_4.parent.description).to eq(ct_2.description)
          expect(tenant_ct_4.vm_or_templates).to match_array([vm_3, vm_4, vm_5])
        end

        it "sets description to CloudTenant#name when CloudTenant#description is empty" do
          ct_4.description = ""
          ct_4.save

          ems_cloud.sync_cloud_tenants_with_tenants

          expect(tenant_ct_4.name).to eq(ct_4.name)
          expect(tenant_ct_4.description).to eq(ct_4.name)
        end

        it "moves out tenant when CloudTenant does not exist under provider's tenant" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree

          ct_4_name = ct_4.name

          ct_4.delete

          ems_cloud.sync_cloud_tenants_with_tenants

          tenant = Tenant.find_by(:name => ct_4_name)

          expect(ems_cloud.source_tenant).to eq(tenant.parent)
        end
      end
    end
  end
end
