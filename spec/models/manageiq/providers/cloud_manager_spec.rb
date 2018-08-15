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
    let(:ems_cloud) { FactoryGirl.create(:ems_openstack_with_authentication, :tenant_mapping_enabled => true) }
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

        it "cleans up created tenant tree when the ems is destroyed" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree
          # 4 cloud tenants, plus the provider tenant and root tenant
          expect(Tenant.count).to eq(6)
          ems_cloud.destroy
          # only the root tenant should remain after destroying the ems
          expect(Tenant.count).to eq(1)
          expect(Tenant.first.name).to eq("My Company")
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

        it "finds and updates existing tenant with orphaned source cloud tenant" do
          ems_cloud.sync_cloud_tenants_with_tenants
          expect_created_tenant_tree

          ct_4.description = "New description"
          ct_4.save

          tenant_ct_4.source = nil
          tenant_ct_4.save!

          ems_cloud.sync_cloud_tenants_with_tenants
          tenant_ct_4.reload

          expect(tenant_ct_4.name).to eq(ct_4.name)
          expect(tenant_ct_4.description).to eq(ct_4.description)
          expect(tenant_ct_4.parent.name).to eq(ct_2.name)
          expect(tenant_ct_4.parent.description).to eq(ct_2.description)
          expect(tenant_ct_4.vm_or_templates).to match_array([vm_3, vm_4])
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

      context "provider's user is changed between two synchronizations" do
        let!(:vm_1) { FactoryGirl.create(:vm_openstack) }
        let!(:vm_2) { FactoryGirl.create(:vm_openstack) }
        let(:ct_name_1) { "c_t_1" }
        let(:ct_name_2) { "c_t_2" }
        let(:ct_name_3) { "c_t_3" }
        let(:provider_tenant) { Tenant.root_tenant.children.first }

        def tenant_from_cloud_tenant_by(vm)
          Tenant.find_by(:name => vm.cloud_tenant.name)
        end

        let(:ct_3) do
          FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_3)
        end

        before do
          vm_1.cloud_tenant.update_attributes!(:parent => ct_3, :ext_management_system => ems_cloud, :name => ct_name_1)
          vm_2.cloud_tenant.update_attributes!(:ext_management_system => ems_cloud, :name => ct_name_2)
        end

        ######
        # ct - Cloud Tenant, t - Tenant
        # =====
        # CloudTenant tree:
        # ct_3 -> ct_1 (vm_1s)
        # ct_2
        #
        # Expected Tenant tree:
        # My Company t
        # -> Provider Tenant
        #    -> t_3 (ct_3's) -> t_1
        #    -> t_2 (ct_2's)
        #######
        it 'creates tenant tree from cloud tenants with VMs' do
          ems_cloud.sync_cloud_tenants_with_tenants

          t_one_ct_vm_one = tenant_from_cloud_tenant_by(vm_1)
          expect(t_one_ct_vm_one.id).to eq(vm_1.cloud_tenant.source_tenant.id)
          expect(t_one_ct_vm_one.parent.id).to eq(ct_3.source_tenant.id)
          expect(t_one_ct_vm_one.children.first).to be_nil
          expect(t_one_ct_vm_one.source_id).to eq(vm_1.cloud_tenant.id)
          expect(t_one_ct_vm_one.source_type).to eq("CloudTenant")

          t_two_ct_vm_two = tenant_from_cloud_tenant_by(vm_2)
          expect(t_two_ct_vm_two.id).to eq(vm_2.cloud_tenant.source_tenant.id)
          expect(t_two_ct_vm_two.parent.id).to eq(provider_tenant.id)
          expect(t_two_ct_vm_two.children.first).to be_nil
          expect(t_two_ct_vm_two.source_id).to eq(vm_2.cloud_tenant.id)
          expect(t_two_ct_vm_two.source_type).to eq("CloudTenant")

          t_three_ct_three = Tenant.find_by(:name => ct_name_3)
          expect(t_three_ct_three.id).to eq(ct_3.source_tenant.id)
          expect(t_three_ct_three.parent.id).to eq(provider_tenant.id)
          expect(t_three_ct_three.children.first.id).to eq(vm_1.cloud_tenant.source_tenant.id)
          expect(t_three_ct_three.source_id).to eq(ct_3.id)
          expect(t_three_ct_three.source_type).to eq("CloudTenant")

          expect(t_one_ct_vm_one.parent.id).to eq(ct_3.source_tenant.id)
          expect(Tenant.find_by(:name => ct_3.name).id).to eq(ct_3.source_tenant.id)

          expect(Tenant.root_tenant.children.first.id).to eq(ct_3.source_tenant.parent.id)
        end

        context "when the new user has cloud tenants with same names than previous provider's user" do
          ######
          # ct - Cloud Tenant, t - Tenant
          # =====
          # CloudTenant tree:
          # ct_3 -> ct_1 (vm_1s)
          # ct_2
          #
          # first tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (ct_3's) -> t_1
          #    -> t_2 (ct_2's)
          #
          ### after changed user with different set of cloud tenants
          ### second synchronization
          # =====
          # CloudTenant tree:
          # new_ct_3(same name) -> new_ct_1 (vm_1s) -> new_ct_4(vm_4's cloud_tenant))
          # new_ct_2
          #
          # second tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (new_ct_3's) -> t_1(new_ct_1's)
          #    -> t_2 (new_ct_2's)
          ######
          let(:ct_1_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_3_new, :name => ct_name_1) }
          let(:ct_2_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_2) }
          let(:ct_3_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_3) }

          it "creates tenant tree from cloud tenants with correct source_tenant relations" do
            expect(CloudTenant.count).to eq(3)
            ems_cloud.sync_cloud_tenants_with_tenants
            expect(Tenant.count).to eq(5)

            tenant_ids = Tenant.ids
            old_cloud_tenant_ids = CloudTenant.ids

            # destroy old cloud tenants and replace them with new
            vm_1.cloud_tenant.destroy
            vm_1.update_attributes!(:cloud_tenant => ct_1_new)
            vm_2.cloud_tenant.destroy
            vm_2.update_attributes!(:cloud_tenant => ct_2_new)
            ct_3.destroy

            expect(CloudTenant.count).to eq(3)
            expect(CloudTenant.ids).not_to match_array(old_cloud_tenant_ids)

            ems_cloud.sync_cloud_tenants_with_tenants
            expect(Tenant.ids).to match_array(tenant_ids)

            t_one_ct_vm_one = tenant_from_cloud_tenant_by(vm_1)
            expect(t_one_ct_vm_one.id).to eq(ct_1_new.source_tenant.id)
            expect(t_one_ct_vm_one.parent.id).to eq(ct_3_new.source_tenant.id)
            expect(t_one_ct_vm_one.children.first).to be_nil
            expect(t_one_ct_vm_one.source_id).to eq(ct_1_new.id)
            expect(t_one_ct_vm_one.source_type).to eq("CloudTenant")

            t_two_ct_vm_two = tenant_from_cloud_tenant_by(vm_2)
            expect(t_two_ct_vm_two.id).to eq(ct_2_new.source_tenant.id)
            expect(t_two_ct_vm_two.parent.id).to eq(provider_tenant.id)
            expect(t_two_ct_vm_two.children.first).to be_nil
            expect(t_two_ct_vm_two.source_id).to eq(ct_2_new.id)
            expect(t_two_ct_vm_two.source_type).to eq("CloudTenant")

            t_three_ct_three = Tenant.find_by(:name => ct_name_3)
            expect(t_three_ct_three.id).to eq(ct_3_new.source_tenant.id)
            expect(t_three_ct_three.parent.id).to eq(provider_tenant.id)
            expect(t_three_ct_three.children.first.id).to eq(ct_1_new.source_tenant.id)
            expect(t_three_ct_three.source_id).to eq(ct_3_new.id)
            expect(t_three_ct_three.source_type).to eq("CloudTenant")

            expect(t_one_ct_vm_one.parent.id).to eq(ct_3_new.source_tenant.id)
            expect(Tenant.find_by(:name => ct_3_new.name).id).to eq(ct_3_new.source_tenant.id)

            expect(Tenant.root_tenant.children.first.id).to eq(ct_3_new.source_tenant.parent.id)
            expect(Tenant.count).to eq(5)
          end
        end

        context "when the new user has cloud tenants with different names than previous provider's user" do
          ######
          # ct - Cloud Tenant, t - Tenant
          # =====
          # CloudTenant tree:
          # ct_3 -> ct_1 (vm_1s)
          # ct_2
          #
          # first tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (ct_3's) -> t_1
          #    -> t_2 (ct_2's)
          #
          ### after changed user with different set of cloud tenants
          ### second synchronization
          # =====
          # CloudTenant tree:
          # new_ct_3(same name) -> new_ct_1 (vm_1s)
          # new_ct_2
          #
          # second tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> new_t_3 (new_ct_3's) -> new_t_1(new_ct_1's)
          #    -> new_t_2 (new_ct_2's)
          #    -> t_1(old - moved out)
          #    -> t_2(old - moved out)
          #    -> t_3(old - moved out)
          ######
          let(:ct_1_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_3_new, :name => ct_name_1 + "X") }
          let(:ct_2_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_2 + "X") }
          let(:ct_3_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_3 + "X") }

          it "creates tenant tree from cloud tenants with correct source_tenant relations" do
            expect(CloudTenant.count).to eq(3)
            ems_cloud.sync_cloud_tenants_with_tenants
            expect(Tenant.count).to eq(5)

            old_cloud_tenant_ids = CloudTenant.ids

            # destroy old cloud tenants and replace them with new
            vm_1.cloud_tenant.destroy
            vm_1.update_attributes!(:cloud_tenant => ct_1_new)
            vm_2.cloud_tenant.destroy
            vm_2.update_attributes!(:cloud_tenant => ct_2_new)
            ct_3.destroy

            expect(CloudTenant.count).to eq(3)
            expect(CloudTenant.ids).not_to match_array(old_cloud_tenant_ids)

            ems_cloud.sync_cloud_tenants_with_tenants

            t_one_ct_vm_one = tenant_from_cloud_tenant_by(vm_1)
            expect(t_one_ct_vm_one.id).to eq(ct_1_new.source_tenant.id)
            expect(t_one_ct_vm_one.parent.id).to eq(ct_3_new.source_tenant.id)
            expect(t_one_ct_vm_one.children.first).to be_nil
            expect(t_one_ct_vm_one.source_id).to eq(ct_1_new.id)
            expect(t_one_ct_vm_one.source_type).to eq("CloudTenant")

            t_two_ct_vm_two = tenant_from_cloud_tenant_by(vm_2)
            expect(t_two_ct_vm_two.id).to eq(ct_2_new.source_tenant.id)
            expect(t_two_ct_vm_two.parent.id).to eq(provider_tenant.id)
            expect(t_two_ct_vm_two.children.first).to be_nil
            expect(t_two_ct_vm_two.source_id).to eq(ct_2_new.id)
            expect(t_two_ct_vm_two.source_type).to eq("CloudTenant")

            t_three_ct_three = Tenant.find_by(:name => ct_name_3 + "X")
            expect(t_three_ct_three.id).to eq(ct_3_new.source_tenant.id)
            expect(t_three_ct_three.parent.id).to eq(provider_tenant.id)
            expect(t_three_ct_three.children.first.id).to eq(ct_1_new.source_tenant.id)
            expect(t_three_ct_three.source_id).to eq(ct_3_new.id)
            expect(t_three_ct_three.source_type).to eq("CloudTenant")

            expect(t_one_ct_vm_one.parent.id).to eq(ct_3_new.source_tenant.id)
            expect(t_three_ct_three.id).to eq(ct_3_new.source_tenant.id)

            provider_tenant = Tenant.root_tenant.children.first
            expect(provider_tenant.id).to eq(ct_3_new.source_tenant.parent.id)
            expect(Tenant.count).to eq(8)

            old_tenant_first = Tenant.find_by(:name => ct_name_1)
            expect(old_tenant_first.id).not_to eq(ct_1_new.source_tenant.id)
            expect(old_tenant_first.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_first.children.first).to be_nil
            expect(old_tenant_first.source_id).to be_nil
            expect(old_tenant_first.source_type).to be_nil

            old_tenant_two = Tenant.find_by(:name => ct_name_2)
            expect(old_tenant_two.id).not_to eq(ct_2_new.source_tenant.id)
            expect(old_tenant_two.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_two.children.first).to be_nil
            expect(old_tenant_first.source_id).to be_nil
            expect(old_tenant_first.source_type).to be_nil

            old_tenant_three = Tenant.find_by(:name => ct_name_3)
            expect(old_tenant_three.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_three.children.first).to be_nil
            expect(old_tenant_three.source_id).to be_nil
            expect(old_tenant_three.source_type).to be_nil
          end
        end

        context "when the new user has lower count of cloud tenants with than previous provider's user" do
          ######
          # ct - Cloud Tenant, t - Tenant
          # =====
          # CloudTenant tree:
          # ct_3 -> ct_1 (vm_1s)
          # ct_2
          #
          # first tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (ct_3's) -> t_1
          #    -> t_2 (ct_2's)
          #
          ### after changed user with different set of cloud tenants
          ### second synchronization
          # =====
          # CloudTenant tree:
          # new_ct_1 (vm_1s)
          #
          # second tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> new_t_1(new_ct_1's)
          #    -> t_2(old - moved out)
          #    -> t_3(old - moved out)
          ######
          let(:ct_1_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_1) }

          it "creates tenant tree from cloud tenants with correct source_tenant relations" do
            expect(CloudTenant.count).to eq(3)
            ems_cloud.sync_cloud_tenants_with_tenants
            expect(Tenant.count).to eq(5)

            old_cloud_tenant_ids = CloudTenant.ids

            # destroy old cloud tenants and replace them with new
            vm_1.cloud_tenant.destroy
            vm_1.update_attributes!(:cloud_tenant => ct_1_new)
            vm_2.cloud_tenant.destroy
            vm_2.destroy
            ct_3.destroy

            expect(CloudTenant.count).to eq(1)
            expect(CloudTenant.ids).not_to match_array(old_cloud_tenant_ids)
            ems_cloud.sync_cloud_tenants_with_tenants

            t_one_ct_vm_one = tenant_from_cloud_tenant_by(vm_1)
            expect(t_one_ct_vm_one.id).to eq(ct_1_new.source_tenant.id)
            expect(t_one_ct_vm_one.parent.id).to eq(provider_tenant.id)
            expect(t_one_ct_vm_one.children.first).to be_nil
            expect(t_one_ct_vm_one.source_id).to eq(ct_1_new.id)
            expect(t_one_ct_vm_one.source_type).to eq("CloudTenant")

            expect(provider_tenant.id).to eq(ct_1_new.source_tenant.parent.id)
            expect(Tenant.count).to eq(5)

            # old tenants (related to deleted cloud tenants) are under provider tenant
            old_tenant_two = Tenant.find_by(:name => ct_name_2)
            expect(old_tenant_two.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_two.children.first).to be_nil
            expect(old_tenant_two.source_id).to be_nil
            expect(old_tenant_two.source_type).to be_nil

            old_tenant_three = Tenant.find_by(:name => ct_name_3)
            expect(old_tenant_three.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_three.children.first).to be_nil
            expect(old_tenant_three.source_id).to be_nil
            expect(old_tenant_three.source_type).to be_nil
          end
        end

        context "when the new user has greater count of cloud tenants with than previous provider's user, some and different name" do
          ######
          # ct - Cloud Tenant, t - Tenant
          # =====
          # CloudTenant tree:
          # ct_3 -> ct_1 (vm_1s)
          # ct_2
          #
          # first tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (ct_3's) -> t_1
          #    -> t_2 (ct_2's)
          #
          ### after changed user with different set of cloud tenants
          ### second synchronization
          # =====
          # CloudTenant tree:
          # new_ct_3(same name) -> new_ct_1 (vm_1s) -> new_ct_4(vm_4's cloud_tenant))
          # new_ct_2
          #
          # second tenant synchronization
          #
          # Expected Tenant tree:
          # My Company t
          # -> Provider Tenant
          #    -> t_3 (new_ct_3's) -> new_t_1(new_ct_1's) -> new_t_4(vm_4's cloud_tenant)
          #    -> new_t_2 (new_ct_2's)
          #    -> t_1(old - moved out)
          #    -> t_2(old - moved out)
          ######
          let(:ct_1_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :parent => ct_3_new, :name => ct_name_1 + "X") }
          let(:ct_2_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_2 + "X") }
          let(:ct_3_new) { FactoryGirl.create(:cloud_tenant_openstack, :ext_management_system => ems_cloud, :name => ct_name_3) }
          let(:ct_name_4) { "ct_name_4" }
          let(:vm_4) do
            vm = FactoryGirl.create(:vm_openstack)
            vm.cloud_tenant.update_attributes!(:parent => ct_1_new, :ext_management_system => ems_cloud, :name => ct_name_4)
            vm
          end

          it "creates tenant tree from cloud tenants with correct source_tenant relations" do
            expect(CloudTenant.count).to eq(3)
            ems_cloud.sync_cloud_tenants_with_tenants
            expect(Tenant.count).to eq(5)

            old_cloud_tenant_ids = CloudTenant.ids

            # destroy old cloud tenants and replace them with new
            vm_1.cloud_tenant.destroy
            vm_1.update_attributes!(:cloud_tenant => ct_1_new)
            vm_2.cloud_tenant.destroy
            vm_2.cloud_tenant.destroy
            vm_2.update_attributes!(:cloud_tenant => ct_2_new)
            ct_3.destroy
            ct_2_new
            vm_4

            expect(CloudTenant.count).to eq(4)
            expect(CloudTenant.ids).not_to match_array(old_cloud_tenant_ids)

            ems_cloud.sync_cloud_tenants_with_tenants

            # testing relations source, parent, children, source_tenant for each tenant
            t_one_ct_vm_one = tenant_from_cloud_tenant_by(vm_1)
            expect(t_one_ct_vm_one.id).to eq(ct_1_new.source_tenant.id)
            expect(t_one_ct_vm_one.parent.id).to eq(ct_3_new.source_tenant.id)
            expect(t_one_ct_vm_one.children.first.id).to eq(vm_4.cloud_tenant.source_tenant.id)
            expect(t_one_ct_vm_one.source_id).to eq(ct_1_new.id)
            expect(t_one_ct_vm_one.source_type).to eq("CloudTenant")

            t_two_ct_vm_two = tenant_from_cloud_tenant_by(vm_2)
            expect(t_two_ct_vm_two.id).to eq(ct_2_new.source_tenant.id)
            expect(t_two_ct_vm_two.parent.id).to eq(provider_tenant.id)
            expect(t_two_ct_vm_two.children.first).to be_nil
            expect(t_two_ct_vm_two.source_id).to eq(ct_2_new.id)
            expect(t_two_ct_vm_two.source_type).to eq("CloudTenant")

            t_three_ct_three = Tenant.find_by(:name => ct_name_3)
            expect(t_three_ct_three.id).to eq(ct_3_new.source_tenant.id)
            expect(t_three_ct_three.parent.id).to eq(provider_tenant.id)
            expect(t_three_ct_three.children.first.id).to eq(ct_1_new.source_tenant.id)
            expect(t_three_ct_three.source_id).to eq(ct_3_new.id)
            expect(t_three_ct_three.source_type).to eq("CloudTenant")
            t_four_ct_four = Tenant.find_by(:name => ct_name_4)
            expect(t_three_ct_three.descendants.ids).to match_array([t_one_ct_vm_one.id, t_four_ct_four.id])

            expect(t_four_ct_four.id).to eq(vm_4.cloud_tenant.source_tenant.id)
            expect(t_four_ct_four.parent.id).to eq(ct_1_new.source_tenant.id)
            expect(t_four_ct_four.children.first).to be_nil
            expect(t_four_ct_four.source_id).to eq(vm_4.cloud_tenant.id)
            expect(t_four_ct_four.source_type).to eq("CloudTenant")

            expect(provider_tenant.id).to eq(ct_3_new.source_tenant.parent.id)
            expect(Tenant.count).to eq(8)

            # old tenants (related to deleted cloud tenants) are under provider tenant
            old_tenant_first = Tenant.find_by(:name => ct_name_1)
            expect(old_tenant_first.id).not_to eq(ct_1_new.source_tenant.id)
            expect(old_tenant_first.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_first.children.first).to be_nil
            expect(old_tenant_first.source_id).to be_nil
            expect(old_tenant_first.source_type).to be_nil

            old_tenant_two = Tenant.find_by(:name => ct_name_2)
            expect(old_tenant_two.id).not_to eq(ct_2_new.source_tenant.id)
            expect(old_tenant_two.parent.id).to eq(provider_tenant.id)
            expect(old_tenant_two.children.first).to be_nil
            expect(old_tenant_first.source_id).to be_nil
            expect(old_tenant_first.source_type).to be_nil
          end
        end
      end
    end
  end
end
