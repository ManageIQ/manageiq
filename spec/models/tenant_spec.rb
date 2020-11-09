RSpec.describe Tenant do
  include_examples ".seed called multiple times", 1

  let(:tenant) { described_class.new(:domain => 'x.com', :parent => default_tenant) }
  let(:user_admin) {
    user = FactoryBot.create(:user_admin)
    allow(user).to receive(:get_timezone).and_return("UTC")
    user
  }

  let(:default_tenant) do
    root_tenant
    described_class.default_tenant
  end

  let(:root_tenant) do
    Tenant.seed
  end

  it "doesn't access database when unchanged model is saved" do
    m = described_class.create!(:parent => described_class.create!)
    expect { m.valid? }.not_to make_database_queries
  end

  describe "#default_tenant" do
    it "has a default tenant" do
      expect(default_tenant).to be_truthy
    end
  end

  describe "#root_tenant" do
    it "has a root tenant" do
      Tenant.seed
      expect(Tenant.root_tenant).to be_truthy
    end

    it "can update the root_tenant" do
      root_tenant.update!(:name => 'newname', :use_config_for_attributes => false)
      expect(root_tenant.reload.name).to eq('newname')
    end
  end

  describe "#default?" do
    it "detects default" do
      expect(default_tenant).to be_default
    end

    it "detects non default" do
      expect(tenant).not_to be_default
    end
  end

  describe "#root?" do
    it "detects root" do
      Tenant.seed
      expect(Tenant.root_tenant).to be_root
    end

    it "detects non root" do
      expect(tenant).not_to be_root
    end
  end

  describe "#tenant?" do
    it "detects tenant" do
      t = Tenant.new(:divisible => true)
      expect(t.tenant?).to be_truthy
    end

    it "detects non tenant" do
      t = Tenant.new(:divisible => false)
      expect(t.tenant?).not_to be_truthy
    end
  end

  describe "#project?" do
    it "detects project" do
      t = Tenant.new(:divisible => false)
      expect(t.project?).to be_truthy
    end

    it "detects non project" do
      t = Tenant.new(:divisible => true)
      expect(t.project?).not_to be_truthy
    end
  end

  describe "#display_type" do
    let(:tenant)  { FactoryBot.build(:tenant) }
    let(:project) { FactoryBot.build(:tenant, :divisible => false) }

    it "detects Tenant" do
      expect(tenant.display_type).to eql  'Tenant'
      expect(project.display_type).not_to eql  'Tenant'
    end

    it "detects Project" do
      expect(project.display_type).to eql 'Project'
      expect(tenant.display_type).not_to eql 'Project'
    end
  end

  describe ".all_tenants" do
    it "returns divisible projects (root and created is divisible)" do
      FactoryBot.create(:tenant, :parent => root_tenant)
      FactoryBot.create(:tenant, :parent => root_tenant, :divisible => false)

      expect(Tenant.all_tenants.count).to eql(2)
    end
  end

  describe ".app_projects" do
    it "returns non-divisible projects (root is divisible))" do
      FactoryBot.create(:tenant, :parent => root_tenant, :divisible => false)
      FactoryBot.create(:tenant, :parent => root_tenant, :divisible => false)

      expect(Tenant.all_projects.count).to eql 2
    end
  end

  context "subtenants and subprojects" do
    before do
      @t1  = FactoryBot.create(:tenant, :parent => root_tenant, :name => "T1")
      @t2  = FactoryBot.create(:tenant, :parent => @t1, :name => "T2")
      @t2p = FactoryBot.create(:tenant, :parent => @t1, :name => "T2 Project", :divisible => false)
      @t3  = FactoryBot.create(:tenant, :parent => @t2, :name => "T3")
      @t3a = FactoryBot.create(:tenant, :parent => @t2, :name => "T3a")
      @t4p = FactoryBot.create(:tenant, :parent => @t3, :name => "T4 Project", :divisible => false)
    end

    it "#all_subtenants" do
      expect(@t1.all_subtenants.to_a).to match_array([@t2, @t3, @t3a])
      expect(@t2.all_subtenants.to_a).to match_array([@t3, @t3a])
    end

    it "#all_subprojects" do
      expect(@t1.all_subprojects.to_a).to match_array([@t2p, @t4p])
      expect(@t2.all_subprojects.to_a).to match_array([@t4p])
    end
  end

  describe "#name" do
    it "has default name" do
      expect(tenant.name).to eq("My Company")
    end

    it "has custom name" do
      tenant.name = "custom"
      expect(tenant.name).to eq("custom")
    end

    it "doesnt read configurations for regular tenant" do
      tenant.name = "custom"
      expect(tenant.name).to eq("custom")
    end

    it "is unique per parent tenant" do
      FactoryBot.create(:tenant, :name => "common", :parent => root_tenant)
      expect { FactoryBot.create(:tenant, :name => "common", :parent => root_tenant) }
        .to raise_error(ActiveRecord::RecordInvalid, /Name should be unique per parent/)
    end

    it "can be the same for different parents" do
      parent1 = FactoryBot.create(:tenant, :name => "parent1", :parent => root_tenant)
      parent2 = FactoryBot.create(:tenant, :name => "parent2", :parent => root_tenant)

      FactoryBot.create(:tenant, :name => "common", :parent => parent1)
      expect do
        FactoryBot.create(:tenant, :name => "common", :parent => parent2)
      end.not_to raise_error
    end

    context "for root_tenants" do
      it "reads settings" do
        stub_settings(:server => {:company => "settings"})
        expect(root_tenant.name).to eq("settings")
      end

      it "can disable reading from configurations" do
        root_tenant.use_config_for_attributes = false
        expect(root_tenant.name).not_to eq("settings")
      end
    end
  end

  it "#parent_name" do
    t1 = FactoryBot.create(:tenant, :name => "T1", :parent => root_tenant)
    t2 = FactoryBot.create(:tenant, :name => "T2", :parent => t1, :divisible => false)

    expect(t2.parent_name).to eql "T1"
    expect(default_tenant.parent_name).to eql nil
  end

  describe "#nil_blanks" do
    it "nulls out blank domain" do
      expect(described_class.create!(:domain => "  ", :parent => root_tenant).domain).to be_nil
    end

    it "nulls out blank subdomain" do
      expect(described_class.create!(:subdomain => "  ", :parent => root_tenant).domain).to be_nil
    end
  end

  context "#validate_only_one_root" do
    it "allows child tenants" do
      stub_settings(:server => {})
      root_tenant.children.create!
    end

    it "only allows one root" do
      described_class.destroy_all
      root_tenant # create a root tenant

      expect { described_class.create! }.to raise_error(ActiveRecord::RecordInvalid, /Parent required/)
    end
  end

  context "#validate_default_tenant" do
    it "fails assigning a group with the wrong tenant" do
      tenant1 = FactoryBot.create(:tenant)
      tenant2 = FactoryBot.create(:tenant)
      g = FactoryBot.create(:miq_group, :tenant => tenant1)
      expect { tenant2.update!(:default_miq_group => g) }
        .to raise_error(ActiveRecord::RecordInvalid, /default group must be a default group for this tenant/)
    end

    # we may want to change this in the future
    it "prevents changing default_miq_group" do
      g = FactoryBot.create(:miq_group, :tenant => tenant)
      expect { tenant.update!(:default_miq_group => g) }
        .to raise_error(ActiveRecord::RecordInvalid, /default group must be a default group for this tenant/)
    end
  end

  context "validate multi region" do
    let(:other_region_id) { ApplicationRecord.id_in_region(1, ApplicationRecord.my_region_number + 1) }

    it "allows same name as tenant in a different region" do
      described_class.create(:name => "GT", :description => "GT Tenant in other region", :id => other_region_id)
      expect(described_class.new(:name => "GT", :description => "GT Tenant in this region").valid?).to be_truthy
    end
  end

  context "#ensure_can_be_destroyed" do
    let(:tenant)       { FactoryBot.create(:tenant) }
    let(:cloud_tenant) { FactoryBot.create(:cloud_tenant) }

    it "wouldn't delete tenant with groups associated" do
      FactoryBot.create(:miq_group, :tenant => tenant)
      expect { tenant.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(tenant.errors.full_messages[0]).to eq("A tenant with groups associated cannot be deleted.")
    end

    it "does not delete tenant created by tenant mapping process" do
      tenant.source = cloud_tenant
      expect { tenant.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
      expect(tenant.errors.full_messages[0]).to eq("A tenant created by tenant mapping cannot be deleted.")
    end

    it "wouldn't delete tenant with subtenants" do
      parent_tenant = FactoryBot.create(:tenant, :parent => root_tenant, :name => "Tenant")
      FactoryBot.create(:tenant, :parent => parent_tenant, :name => "Subtenant")
      expect { parent_tenant.destroy! }.to raise_error(Ancestry::AncestryException)
    end

    it "wouldn't delete tenant with subprojects" do
      parent_tenant = FactoryBot.create(:tenant, :parent => root_tenant, :name => "Tenant")
      FactoryBot.create(:tenant, :parent => parent_tenant, :name => "Subtenant", :divisible => false)
      expect { parent_tenant.destroy! }.to raise_error(Ancestry::AncestryException)
    end
  end

  describe "#destroy_with_subtree" do
    before do
      root_tenant = Tenant.seed
      @parent_tenant = FactoryBot.create(:tenant, :parent => root_tenant)
      @sub_tenant = FactoryBot.create(:tenant, :parent => @parent_tenant)
      FactoryBot.create(:tenant, :parent => @sub_tenant)
      sub_sub_tenant = FactoryBot.create(:tenant, :parent => @sub_tenant)
      FactoryBot.create(:tenant, :parent =>sub_sub_tenant)

      @sub_project = FactoryBot.create(:tenant, :parent => @parent_tenant, :divisible => false)
      FactoryBot.create(:tenant, :parent => @sub_project, :divisible => false)
      FactoryBot.create(:tenant, :parent => @sub_project, :divisible => false)
    end

    it "deletes tenant with all sub-tenants" do
      expect(Tenant.count).to eq(9)
      @sub_tenant.destroy_with_subtree
      expect(Tenant.count).to eq(5)
    end

    it "deletes project with all sub-projects" do
      @sub_project.destroy_with_subtree
      expect(Tenant.count).to eq(6)
    end

    it "deletes tenant with all sub-projects and sub-tenants" do
      @parent_tenant.destroy_with_subtree
      expect(Tenant.count).to eq(1)
    end
  end

  describe "#description" do
    it "has description" do
      tenant.update(:description => 'very important vm')
      expect(tenant.description).not_to be_nil
    end
  end

  describe "#reads_settings" do
    it "defaults to false" do
      expect(tenant).not_to be_use_config_for_attributes
    end

    it "defaults to true for root_tenant" do
      expect(root_tenant).to be_use_config_for_attributes
    end
  end

  context "#admins" do
    let(:self_service_role) { FactoryBot.create(:miq_user_role, :settings => {:restrictions => {:vms => :user}}) }
    let(:admin_with_brand) { FactoryBot.create(:miq_user_role, :name => "tenant_admin-brand-master") }

    let(:tenant1) { FactoryBot.create(:tenant) }
    let(:tenant1_admins) do
      FactoryBot.create(:miq_group,
                         :miq_user_role => admin_with_brand,
                         :tenant        => tenant1
                        )
    end
    let(:tenant1_users) do
      FactoryBot.create(:miq_group,
                         :tenant        => tenant1,
                         :miq_user_role => self_service_role)
    end
    let(:admin) { FactoryBot.create(:user, :miq_groups => [tenant1_users, tenant1_admins]) }
    let(:user1) { FactoryBot.create(:user, :miq_groups => [tenant1_users]) }
    let(:user2) { FactoryBot.create(:user) }

    it "has users" do
      admin
      user1
      user2
      expect(tenant1.users).to include(admin)
      expect(tenant1.users).to include(user1)
      expect(tenant1.users).not_to include(user2)
    end
  end

  context "#miq_ae_domains" do
    let(:t1) { FactoryBot.create(:tenant, :name => "T1", :parent => root_tenant) }
    let(:t2) { FactoryBot.create(:tenant, :name => "T2", :parent => root_tenant) }
    let(:dom1) { FactoryBot.create(:miq_ae_domain, :tenant => t1, :name => 'DOM1', :priority => 20) }
    let(:dom2) { FactoryBot.create(:miq_ae_domain, :tenant => t2, :name => 'DOM2', :priority => 40) }
    let(:t1_1) { FactoryBot.create(:tenant, :name => 'T1_1', :domain => 'a.a.com', :parent => t1) }
    let(:t2_2) { FactoryBot.create(:tenant, :name => 'T2_1', :domain => 'b.b.com', :parent => t2) }

    context "reset priority" do
      it "#reset_domain_priority_by_ordered_ids" do
        FactoryBot.create(:miq_ae_system_domain, :name => 'ManageIQ', :priority => 0,
                           :tenant_id => root_tenant.id)
        FactoryBot.create(:miq_ae_system_domain, :name => 'Redhat', :priority => 1,
                           :tenant_id => root_tenant.id)
        dom3 = FactoryBot.create(:miq_ae_domain, :name => 'A', :tenant_id => root_tenant.id)
        dom4 = FactoryBot.create(:miq_ae_domain, :name => 'B', :tenant_id => root_tenant.id)

        expect(root_tenant.visible_domains.collect(&:name)).to eq(%w(B A Redhat ManageIQ))
        ids = [dom4.id, dom3.id]
        root_tenant.reset_domain_priority_by_ordered_ids(ids)
        expect(root_tenant.visible_domains.collect(&:name)).to eq(%w(A B Redhat ManageIQ))
        dom4.reload
        expect(dom4.priority).to eq(2)
      end

      it "#reset_domain_priority_by_ordered_ids by subtenant" do
        FactoryBot.create(:miq_ae_system_domain, :name => 'ManageIQ', :priority => 0,
                           :tenant_id => root_tenant.id)
        FactoryBot.create(:miq_ae_system_domain, :name => 'Redhat', :priority => 1,
                           :tenant_id => root_tenant.id)
        FactoryBot.create(:miq_ae_domain, :name => 'T1_A', :tenant_id => t1.id)
        FactoryBot.create(:miq_ae_domain, :name => 'T1_B', :tenant_id => t1.id)
        dom5 = FactoryBot.create(:miq_ae_domain, :name => 'T1_1_A', :tenant_id => t1_1.id)
        dom6 = FactoryBot.create(:miq_ae_domain, :name => 'T1_1_B', :tenant_id => t1_1.id)
        expect(t1_1.visible_domains.collect(&:name)).to eq(%w(T1_1_B T1_1_A T1_B T1_A Redhat ManageIQ))
        ids = [dom6.id, dom5.id]
        t1_1.reset_domain_priority_by_ordered_ids(ids)
        expect(t1_1.visible_domains.collect(&:name)).to eq(%w(T1_1_A T1_1_B T1_B T1_A Redhat ManageIQ))
      end
    end

    it '#sequenceable_domains' do
      t1_1
      FactoryBot.create(:miq_ae_domain, :name => 'DOM15', :priority => 15,
                         :tenant_id => t1_1.id)
      FactoryBot.create(:miq_ae_system_domain, :name => 'DOM10', :priority => 10,
                         :tenant_id => root_tenant.id, :enabled => false)

      expect(t1_1.sequenceable_domains.collect(&:name)).to eq(%w(DOM15))
    end

    context "visibility" do
      before do
        dom1
        dom2
        FactoryBot.create(:miq_ae_domain, :name => 'DOM15', :priority => 15,
                           :tenant_id => root_tenant.id)
        FactoryBot.create(:miq_ae_domain, :name => 'DOM10', :priority => 10,
                           :tenant_id => root_tenant.id, :enabled => false)
        FactoryBot.create(:miq_ae_domain, :name => 'DOM3', :priority => 3,
                           :tenant_id => t1_1.id)
        FactoryBot.create(:miq_ae_domain, :name => 'DOM5', :priority => 7,
                           :tenant_id => t1_1.id)
        FactoryBot.create(:miq_ae_domain, :name => 'DOM4', :priority => 5,
                           :tenant_id => t2_2.id)
      end

      # This spec is here to confirm that we don't mutate the memoized
      # ancestor_ids value when calling `Tenant#visible_domains`.
      it "does not affect the memoized ancestor_ids variable" do
        expected_ancestor_ids = t1_1.ancestor_ids.dup  # dup required, don't remove
        t1_1.visible_domains
        expect(t1_1.ancestor_ids).to eq(expected_ancestor_ids)
      end

      it "#visibile_domains sub_tenant" do
        t1_1
        expect(t1_1.visible_domains.collect(&:name)).to eq(%w(DOM5 DOM3 DOM1 DOM15 DOM10))
      end

      it "#enabled_domains sub_tenant" do
        t1_1
        expect(t1_1.enabled_domains.collect(&:name)).to eq(%w(DOM5 DOM3 DOM1 DOM15))
      end

      it "#editable domains sub_tenant" do
        t1_1
        expect(t1_1.editable_domains.collect(&:name)).to eq(%w(DOM5 DOM3))
      end

      it "#visible_domains tenant" do
        t2
        expect(t2.visible_domains.collect(&:name)).to eq(%w(DOM2 DOM15 DOM10))
      end
    end

    it "tenant domains" do
      dom1
      dom2
      expect(t1.ae_domains.collect(&:name)).to match_array([dom1.name])
    end

    it "delete tenant" do
      dom1
      dom2
      t1.destroy
      expect(MiqAeDomain.all.collect(&:name)).to match_array([dom2.name])
    end

    it "domain belongs to tenant" do
      dom1
      expect(dom1.tenant.name).to eq(t1.name)
    end

    it "no editable domains available for current tenant" do
      t1_1
      FactoryBot.create(:miq_ae_system_domain,
                         :name      => 'non_editable',
                         :priority  => 3,
                         :tenant_id => t1_1.id)
      expect(t1_1.any_editable_domains?).to eq(false)
    end

    it "editable domains available for current_tenant" do
      t1_1
      FactoryBot.create(:miq_ae_domain,
                         :name      => 'editable',
                         :priority  => 3,
                         :tenant_id => t1_1.id)
      expect(t1_1.any_editable_domains?).to eq(true)
    end
  end

  describe ".set_quotas" do
    let(:tenant)  { FactoryBot.build(:tenant, :parent => default_tenant) }

    it "can set quotas" do
      tenant.set_quotas(:vms_allocated => {:value => 20})

      expect(tenant.tenant_quotas.length).to eql 1
    end

    it "adds new quotas" do
      default_tenant.set_quotas(:cpu_allocated => {:value => 1024}, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas.order(:name)
      expect(tq.length).to eql 3

      tq_cpu = tq[0]
      expect(tq_cpu.name).to eql "cpu_allocated"
      expect(tq_cpu.unit).to eql "fixnum"
      expect(tq_cpu.format).to eql "general_number_precision_0"
      expect(tq_cpu.value).to eql 1024.0

      tq_mem = tq[1]
      expect(tq_mem.name).to eql "mem_allocated"
      expect(tq_mem.unit).to eql "bytes"
      expect(tq_mem.format).to eql "gigabytes_human"
      expect(tq_mem.value).to eql 4096.0

      tq_vms = tq[2]
      expect(tq_vms.name).to eql "vms_allocated"
      expect(tq_vms.unit).to eql "fixnum"
      expect(tq_vms.format).to eql "general_number_precision_0"
      expect(tq_vms.value).to eql 20.0
    end

    it "updates existing quotas" do
      default_tenant.set_quotas(:vms_allocated => {:value => 20})

      tq = default_tenant.tenant_quotas.last
      expect(tq.value).to eql 20.0

      default_tenant.set_quotas(:vms_allocated => {:value => 40})

      tq.reload
      expect(tq.value).to eql 40.0
    end

    it "deletes existing quotas" do
      default_tenant.set_quotas(:cpu_allocated => {:value => 1024}, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 3

      default_tenant.set_quotas(:vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 2
      expect(tq.map(&:name).sort).to eql %w(mem_allocated vms_allocated)
    end

    it "deletes existing quotas when nil value is passed" do
      default_tenant.set_quotas(:cpu_allocated => {:value => 1024}, :vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 3

      default_tenant.set_quotas(:cpu_allocated => {:value => nil})

      tq = default_tenant.tenant_quotas
      expect(tq.length).to eql 0
    end
  end

  describe ".get_quotas" do
    let(:tenant)  { FactoryBot.build(:tenant, :parent => default_tenant) }

    it "can get quotas" do
      expect(tenant.get_quotas).not_to be_empty
    end

    it "gets existing quotas" do
      default_tenant.set_quotas(:vms_allocated => {:value => 20}, :mem_allocated => {:value => 4096})

      expected = {
        :vms_allocated     => {
          :unit          => "fixnum",
          :value         => 20.0,
          :warn_value    => nil,
          :format        => "general_number_precision_0",
          :text_modifier => "Count",
          :description   => "Allocated Number of Virtual Machines"
        },
        :mem_allocated     => {
          :unit          => "bytes",
          :value         => 4096.0,
          :warn_value    => nil,
          :format        => "gigabytes_human",
          :text_modifier => "GB",
          :description   => "Allocated Memory in GB"
        },
        :storage_allocated => {
          :unit          => :bytes,
          :value         => nil,
          :warn_value    => nil,
          :format        => :gigabytes_human,
          :text_modifier => "GB",
          :description   => "Allocated Storage in GB"
        }
      }

      expect(default_tenant.get_quotas[:vms_allocated]).to     eql expected[:vms_allocated]
      expect(default_tenant.get_quotas[:mem_allocated]).to     eql expected[:mem_allocated]
      expect(default_tenant.get_quotas[:storage_allocated]).to eql expected[:storage_allocated]
    end
  end

  describe ".used_quotas" do
    let(:tenant) { FactoryBot.create(:tenant, :parent => default_tenant) }
    let(:ems) { FactoryBot.create(:ems_vmware, :name => 'ems', :tenant => tenant) }

    let(:vm1) do
      FactoryBot.create(
        :vm_vmware,
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryBot.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryBot.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
        )
      )
    end

    let(:vm2) do
      FactoryBot.create(
        :vm_vmware,
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryBot.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryBot.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
        )
      )
    end

    let(:template) do
      FactoryBot.create(
        :miq_template,
        :name                  => "test",
        :location              => "test.vmx",
        :vendor                => "vmware",
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryBot.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryBot.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
        )
      )
    end

    before do
      tenant.set_quotas(
        :vms_allocated       => {:value => 20},
        :mem_allocated       => {:value => 4096},
        :cpu_allocated       => {:value => 4},
        :storage_allocated   => {:value => 123_456_789},
        :templates_allocated => {:value => 10}
      )
    end

    it "can get the used quota values" do
      vm1
      template

      used = tenant.used_quotas
      expect(used[:vms_allocated][:value]).to       eql 1
      expect(used[:mem_allocated][:value]).to       eql 1_073_741_824
      expect(used[:cpu_allocated][:value]).to       eql 1
      expect(used[:storage_allocated][:value]).to   eql 12_345_678
      expect(used[:templates_allocated][:value]).to eql 1
    end

    it "ignores retired vms" do
      vm1
      vm2.update_attribute(:retired, true)

      used = tenant.used_quotas
      expect(used[:vms_allocated][:value]).to       eql 1
      expect(used[:mem_allocated][:value]).to       eql 1_073_741_824
      expect(used[:cpu_allocated][:value]).to       eql 1
      expect(used[:storage_allocated][:value]).to   eql 12_345_678
      expect(used[:templates_allocated][:value]).to eql 0
    end
  end

  context "quota allocation" do
    let(:parent_tenant) { FactoryBot.create(:tenant, :parent => default_tenant) }
    let(:child_tenant1) { FactoryBot.create(:tenant, :parent => parent_tenant) }
    let(:child_tenant2) { FactoryBot.create(:tenant, :parent => parent_tenant) }
    let(:child_tenant3) { FactoryBot.create(:tenant, :parent => parent_tenant) }

    before do
      parent_tenant.set_quotas(
        :vms_allocated       => {:value => 20},
        :mem_allocated       => {:value => 4096},
        :cpu_allocated       => {:value => 10},
        :storage_allocated   => {:value => 200_000_000},
        :templates_allocated => {:value => 10}
      )

      child_tenant1.set_quotas(
        :vms_allocated       => {:value => 5},
        :mem_allocated       => {:value => 1024},
        :cpu_allocated       => {:value => 4},
        :storage_allocated   => {:value => 100_000_000},
        :templates_allocated => {:value => 1}
      )

      child_tenant2.set_quotas(
        :vms_allocated       => {:value => 1},
        :mem_allocated       => {:value => 512},
        :cpu_allocated       => {:value => 2},
        :storage_allocated   => {:value => 50_000_000},
        :templates_allocated => {:value => 4}
      )

      allow_any_instance_of(TenantQuota).to receive_messages(:used => 2)
    end

    it "calculates quotas allocated to child tenants" do
      parent_tenant
      child_tenant1
      child_tenant2

      allocated = parent_tenant.allocated_quotas
      expect(allocated[:vms_allocated][:value]).to       eql 6.0
      expect(allocated[:mem_allocated][:value]).to       eql 1536.0
      expect(allocated[:cpu_allocated][:value]).to       eql 6.0
      expect(allocated[:storage_allocated][:value]).to   eql 150_000_000.0
      expect(allocated[:templates_allocated][:value]).to eql 5.0
    end

    it "calculates quotas available to be allocated to child tenants" do
      parent_tenant
      child_tenant1
      child_tenant2
      available = parent_tenant.available_quotas
      expect(available[:vms_allocated][:value]).to       eql 12.0
      expect(available[:mem_allocated][:value]).to       eql 2558.0
      expect(available[:cpu_allocated][:value]).to       eql 2.0
      expect(available[:storage_allocated][:value]).to   eql 49_999_998.0
      expect(available[:templates_allocated][:value]).to eql 3.0
    end

    it "gets combined quotas (set, used, allocated and available)" do
      parent_tenant
      child_tenant1
      child_tenant2

      combined = parent_tenant.combined_quotas

      expect(combined[:vms_allocated][:value]).to             eql 20.0
      expect(combined[:mem_allocated][:value]).to             eql 4096.0
      expect(combined[:cpu_allocated][:value]).to             eql 10.0
      expect(combined[:storage_allocated][:value]).to         eql 200_000_000.0
      expect(combined[:templates_allocated][:value]).to       eql 10.0

      expect(combined[:vms_allocated][:allocated]).to         eql 6.0
      expect(combined[:mem_allocated][:allocated]).to         eql 1536.0
      expect(combined[:cpu_allocated][:allocated]).to         eql 6.0
      expect(combined[:storage_allocated][:allocated]).to     eql 150_000_000.0
      expect(combined[:templates_allocated][:allocated]).to   eql 5.0

      expect(combined[:vms_allocated][:available]).to         eql 12.0
      expect(combined[:mem_allocated][:available]).to         eql 2558.0
      expect(combined[:cpu_allocated][:available]).to         eql 2.0
      expect(combined[:storage_allocated][:available]).to     eql 49_999_998.0
      expect(combined[:templates_allocated][:available]).to   eql 3.0

      expect(combined[:vms_allocated][:used]).to              eql 2
      expect(combined[:mem_allocated][:used]).to              eql 2
      expect(combined[:cpu_allocated][:used]).to              eql 2
      expect(combined[:storage_allocated][:used]).to          eql 2
      expect(combined[:templates_allocated][:used]).to        eql 2
    end

    it "combined quotas get used value when no quotas are defined for tenant" do
      combined = child_tenant3.combined_quotas

      expect(combined[:vms_allocated][:used]).to              eql 2
      expect(combined[:mem_allocated][:used]).to              eql 2
      expect(combined[:cpu_allocated][:used]).to              eql 2
      expect(combined[:storage_allocated][:used]).to          eql 2
      expect(combined[:templates_allocated][:used]).to        eql 2

      expect(combined[:vms_allocated][:value]).to             eql 0.0
      expect(combined[:mem_allocated][:value]).to             eql 0.0
      expect(combined[:cpu_allocated][:value]).to             eql 0.0
      expect(combined[:storage_allocated][:value]).to         eql 0.0
      expect(combined[:templates_allocated][:value]).to       eql 0.0
    end
  end

  describe ".tenant_and_project_names" do
    before do
      stub_settings(:server => {:company => "root"})
    end

    # root
    #   ten1
    #     ten2
    it "builds names with dots" do
      ten1 = FactoryBot.create(:tenant, :name => "ten1", :parent => root_tenant)
      ten2 = FactoryBot.create(:tenant, :name => "ten2", :parent => ten1)

      User.with_user(user_admin) do
        tenants, projects = Tenant.tenant_and_project_names
        expect(tenants).to eq([["root", root_tenant.id], ["root/ten1", ten1.id], ["root/ten1/ten2", ten2.id]])
        expect(projects).to be_empty
      end
    end

    # root
    #   proj1
    #   proj2
    it "separates projects" do
      proj2 = FactoryBot.create(:tenant, :name => "proj2", :divisible => false, :parent => root_tenant)
      proj1 = FactoryBot.create(:tenant, :name => "proj1", :divisible => false, :parent => root_tenant)

      User.with_user(user_admin) do
        tenants, projects = Tenant.tenant_and_project_names
        expect(tenants).to eq([["root", root_tenant.id]])
        expect(projects).to eq([["root/proj1", proj1.id], ["root/proj2", proj2.id]])
      end
    end

    # root
    #   proj3
    #   ten1
    #     proj1
    #   ten2
    #     proj2
    #   ten3
    it "separates tenants from projects" do
      FactoryBot.create(:tenant, :name => "ten3", :parent => root_tenant)
      ten1 = FactoryBot.create(:tenant, :name => "ten1", :parent => root_tenant)
      ten2 = FactoryBot.create(:tenant, :name => "ten2", :parent => root_tenant)
      FactoryBot.create(:tenant, :name => "proj2", :divisible => false, :parent => ten2)
      FactoryBot.create(:tenant, :name => "proj1", :divisible => false, :parent => ten1)
      FactoryBot.create(:tenant, :name => "proj3", :divisible => false, :parent => root_tenant)

      User.with_user(user_admin) do
        tenants, projects = Tenant.tenant_and_project_names
        expect(tenants.map(&:first)).to eq(%w(root root/ten1 root/ten2 root/ten3))
        expect(tenants.first.last).to eq(root_tenant.id)

        expect(projects.map(&:first)).to eq(%w(root/proj3 root/ten1/proj1 root/ten2/proj2))
      end
    end
  end

  describe ".build_tenant_tree" do
    let!(:tenant)   { FactoryBot.create(:tenant) }
    let!(:tenantA)  { FactoryBot.create(:tenant, :parent => tenant) }
    let!(:tenantA1) { FactoryBot.create(:tenant, :parent => tenantA) }

    it "returns subtenants of a tenant" do
      expected_array = [{:name => tenantA.name, :id => tenantA.id, :parent => tenant.id},
                        {:name => tenantA1.name, :id => tenantA1.id, :parent => tenantA.id}]
      expect(tenant.build_tenant_tree).to match_array(expected_array)
    end

    it "returns [] of a tenant without subtenants" do
      expect(tenantA1.build_tenant_tree).to be_empty
    end
  end

  describe "setting a parent for a new record" do
    it "passes back the parent assigned" do
      tenant.save!
      sub_tenant = FactoryBot.build(:tenant, :parent => Tenant.root_tenant)

      expect(sub_tenant.parent = tenant).to eq(tenant)
    end

    it "passes back the parent_id assigned" do
      tenant.save!
      sub_tenant = FactoryBot.build(:tenant, :parent => Tenant.root_tenant)

      expect(sub_tenant.parent_id = tenant.id).to eq(tenant.id)
    end
  end

  describe "#create" do
    it "properly creates a default group" do
      # create a tenant, but one that doesn't have a default_miq_group
      # this is only possibly during an upgrade
      tenant.save!
      tenant.default_miq_group.delete
      # We are using update_attribute to create an invalid tenant.
      # rubocop:disable Rails/SkipsModelValidations
      tenant.update_attribute(:default_miq_group_id, nil)
      # rubocop:enable Rails/SkipsModelValidations
      # lets make sure the tenant doesn't get assigned this user created group (the bug)
      false_group = FactoryBot.create(:miq_group, :tenant_id => tenant.id)

      # 20151021174140_assign_tenant_default_group.rb
      tenant.send(:create_tenant_group)

      expect(tenant.default_miq_group).not_to eq(false_group)
      expect(tenant.default_miq_group).to be_tenant_group
    end

    context 'dynamic product features' do
      let!(:miq_product_feature_1) { FactoryBot.create(:miq_product_feature, :identifier => 'dialog_edit_editor') }
      let!(:miq_product_feature_2) { FactoryBot.create(:miq_product_feature, :identifier => 'dialog_new_editor') }

      let(:tenant_product_feature) { FactoryBot.create(:tenant) }

      it "properly creates a related product feature" do
        features = tenant_product_feature.miq_product_features.map { |x| x.slice(:name, :description, :identifier, :feature_type) }
        expect(features).to match_array([{"name" => "#{miq_product_feature_1.name} (#{tenant_product_feature.name})", "description" => "#{miq_product_feature_1.description} for tenant #{tenant_product_feature.name}",
                                          "identifier" => "dialog_edit_editor_tenant_#{tenant_product_feature.id}", "feature_type" => "admin"},
                                         {"name" => "#{miq_product_feature_2.name} (#{tenant_product_feature.name})",
                                          "description" => "#{miq_product_feature_2.description} for tenant #{tenant_product_feature.name}",
                                          "identifier" => "dialog_new_editor_tenant_#{tenant_product_feature.id}", "feature_type" => "admin"}])
      end

      describe "#create_miq_product_features_for_tenant_nodes" do
        let(:tenant_product_feature) { FactoryBot.create(:tenant) }

        it "creates product features for tenant nodes" do
          expect(tenant_product_feature.create_miq_product_features_for_tenant_nodes).to match_array(["dialog_edit_editor_tenant_#{tenant_product_feature.id}", "dialog_new_editor_tenant_#{tenant_product_feature.id}"])
        end
      end

      it "destroys product features on destroy" do
        tenant_product_feature.destroy

        expect(MiqProductFeature.where(:identifier => ["dialog_edit_editor_tenant_#{tenant_product_feature.id}", "ab_group_admin_tenant_#{tenant_product_feature.id}"], :feature_type => 'tenant').count).to be_zero
      end
    end
  end

  context "using more regions with factory" do
    let!(:other_region) { FactoryGirl.create(:miq_region) }

    context "without MiqRegion.seed" do
      it "uses other region" do
        expect(MiqRegion.count).to eq(1)
        exception_message = "You need to seed default MiqRegion with MiqRegion.seed"
        expect { FactoryGirl.create(:tenant, :in_other_region,  :other_region => other_region) }.to raise_error(exception_message)
      end
    end

    context "with MiqRegion.seed" do
      before do
        MiqRegion.seed
      end

      let!(:tenant) { FactoryGirl.create(:tenant, :in_other_region, :other_region => other_region) }

      it "uses other region" do
        expect(MiqRegion.count).to eq(2)
        expect(tenant.miq_region.region).to eq(other_region.region)
        expect(tenant.default_miq_group.miq_region.region).to eq(other_region.region)
      end

      it "raises error when region is not passed" do
        exception_message = "You need to pass specific region  with :other_region: \n"\
                            "FactoryGirl.create(:tenant, :in_other_region, :other_region => <region>) "
        expect { FactoryGirl.create(:tenant, :in_other_region) }.to raise_error(exception_message)
      end

      let!(:root_tenant_other_region) do
        tenant_other_region = FactoryGirl.create(:tenant, :in_other_region, :other_region => other_region)
        tenant_other_region.update_attribute(:parent, nil) # rubocop:disable Rails/SkipsModelValidations
        tenant_other_region
      end

      let!(:root_tenant) { Tenant.seed }

      it "creates root tenant in other region" do
        expect(root_tenant.root?).to be_truthy
        expect(Tenant.find(root_tenant_other_region.id).root?).to be_truthy
        expect(Tenant.find(root_tenant_other_region.id).parent).to be_nil
        expect(MiqRegion.my_region_number).not_to eq(MiqRegion.find_by(:region => root_tenant_other_region.region_id).region)
      end
    end
  end
end
