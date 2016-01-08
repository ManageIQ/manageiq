require "spec_helper"

describe Tenant do
  include_examples ".seed called multiple times"

  let(:config) { {} }
  let(:tenant) { described_class.new(:domain => 'x.com', :parent => default_tenant) }

  let(:default_tenant) do
    root_tenant
    described_class.default_tenant
  end

  let(:root_tenant) do
    Tenant.seed
  end

  before do
    stub_server_configuration(config)
  end

  describe "#default_tenant" do
    it "has a default tenant" do
      expect(default_tenant).to be
    end
  end

  describe "#root_tenant" do
    it "has a root tenant" do
      Tenant.seed
      expect(Tenant.root_tenant).to be
    end

    it "can update the root_tenant" do
      root_tenant.update_attributes!(:name => 'newname', :use_config_for_attributes => false)
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
    let(:tenant)  { FactoryGirl.build(:tenant) }
    let(:project) { FactoryGirl.build(:tenant, :divisible => false) }

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
      FactoryGirl.create(:tenant, :parent => root_tenant)
      FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)

      expect(Tenant.all_tenants.count).to eql(2)
    end
  end

  describe ".app_projects" do
    it "returns non-divisible projects (root is divisible))" do
      FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)
      FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)

      expect(Tenant.all_projects.count).to eql 2
    end
  end

  context "subtenants and subprojects" do
    before do
      @t1  = FactoryGirl.create(:tenant, :parent => root_tenant, :name => "T1")
      @t2  = FactoryGirl.create(:tenant, :parent => @t1, :name => "T2")
      @t2p = FactoryGirl.create(:tenant, :parent => @t1, :name => "T2 Project", :divisible => false)
      @t3  = FactoryGirl.create(:tenant, :parent => @t2, :name => "T3")
      @t3a = FactoryGirl.create(:tenant, :parent => @t2, :name => "T3a")
      @t4p = FactoryGirl.create(:tenant, :parent => @t3, :name => "T4 Project", :divisible => false)
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
    let(:config) { {:server => {:company => "settings"}} }

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
      FactoryGirl.create(:tenant, :name => "common", :parent => root_tenant)
      expect do
        FactoryGirl.create(:tenant, :name => "common", :parent => root_tenant)
      end.to raise_error
    end

    it "can be the same for different parents" do
      parent1 = FactoryGirl.create(:tenant, :name => "parent1", :parent => root_tenant)
      parent2 = FactoryGirl.create(:tenant, :name => "parent2", :parent => root_tenant)

      FactoryGirl.create(:tenant, :name => "common", :parent => parent1)
      expect do
        FactoryGirl.create(:tenant, :name => "common", :parent => parent2)
      end.not_to raise_error
    end

    context "for root_tenants" do
      it "reads settings" do
        expect(root_tenant.name).to eq("settings")
      end

      it "can disable reading from configurations" do
        root_tenant.use_config_for_attributes = false
        expect(root_tenant.name).not_to eq("settings")
      end
    end
  end

  it "#parent_name" do
    t1 = FactoryGirl.create(:tenant, :name => "T1", :parent => root_tenant)
    t2 = FactoryGirl.create(:tenant, :name => "T2", :parent => t1, :divisible => false)

    expect(t2.parent_name).to eql "T1"
    expect(default_tenant.parent_name).to eql nil
  end

  describe "#logo" do
    # would prefer if url was nil, but this is how paperclip works
    # but basically checking tht it is not /uploads/custom_logo
    it "has bogus url (but not typical custom logo)" do
      tenant.save!
      expect(tenant.logo.url).to match(/missing/)
    end

    it "has the correct logo url" do
      tenant.update_attributes!(:logo_file_name => "custom_logo.png")
      expect(tenant.logo.url).to eq("/uploads/custom_logo.png")
    end

    it "points to the correct logo file" do
      tenant.update_attributes!(:logo_file_name => "custom_logo.png")
      expect(tenant.logo.path).to eq(Rails.root.join("public/uploads/custom_logo.png").to_s)
    end

    it "has no logo for root_tenant" do
      expect(root_tenant.logo.url).to match(/missing/)
    end

    context "with server configurations" do
      let(:config) { {:server => {:custom_logo => true}} }

      it "uses configurations value for root_tenant" do
        expect(root_tenant.logo.url).to eq("/uploads/custom_logo.png")
      end

      it "overrides configurations for root_tenant" do
        root_tenant.update_attributes(:logo_file_name => "different.png", :use_config_for_attributes => false)
        expect(root_tenant.logo.url).to eq("/uploads/different.png")
      end

      # would prefer if url was nil, but this is how paperclip works
      it "does not use configurations for regular tenant" do
        tenant.save!
        expect(tenant.logo.url).to match(/missing/)
      end
    end
  end

  describe "#logo?" do
    let(:settings) { {:server => {:custom_logo => false}} }

    it "knows there is a logo" do
      tenant.logo_file_name = "custom_logo.png"
      expect(tenant).to be_logo
    end

    it "knows there is no logo" do
      expect(tenant).not_to be_logo
    end

    context "for root_tenant" do
      it "knows there is no logo from configuration" do
        expect(root_tenant).not_to be_logo
      end

      it "knows there is a logo overriding configuration" do
        root_tenant.logo_file_name = "custom_logo.png"
        root_tenant.use_config_for_attributes = false
        expect(root_tenant).to be_logo
      end

      context "#with custom_logo configuration" do
        let(:config) { {:server => {:custom_logo => true}} }

        it "knows there is a logo from configuration" do
          expect(root_tenant).to be_logo
        end

        it "knows there is no logo when not using config" do
          root_tenant.use_config_for_attributes = false
          expect(root_tenant).not_to be_logo
        end
      end
    end
  end

  # NOTE: much of this functionality was tested in #logo?
  describe "#logo_file_name" do
    it "has custom filename" do
      tenant.logo_file_name = "custom_logo.png"
      expect(tenant.logo_file_name).to eq("custom_logo.png")
    end
  end

  describe "#logo_content_type" do
    it "has custom content_type" do
      tenant.logo_content_type = "image/jpg"
      expect(tenant.logo_content_type).to eq("image/jpg")
    end

    it "has no custom content_type" do
      expect(tenant.logo_content_type).to be_nil
    end

    context "for root_tenant" do
      it "has custom content_type" do
        expect(root_tenant.logo_content_type).to eq("image/png")
      end

      context "#with custom logo configuration" do
        let(:settings) { {:server => {:custom_logo => true}} }

        it "has custom content_type" do
          expect(root_tenant.logo_content_type).to eq("image/png")
        end
      end
    end
  end

  describe "#login_logo" do
    # NOTE: initializers/paperclip.rb sets up :default_login_logo

    it "has a default login image" do
      tenant.save!
      expect(tenant.login_logo.url).to match(/login-screen-logo.png/)
    end

    it "has a default login image for root_tenant" do
      expect(root_tenant.login_logo.url).to match(/login-screen-logo.png/)
    end

    it "has custom login logo" do
      tenant.update_attributes(:login_logo_file_name => "custom_login_logo.png")
      expect(tenant.login_logo.url).to match(/custom_login_logo.png/)
    end

    context "with custom login logo configuration" do
      let(:config) { {:server => {:custom_login_logo => true}} }

      it "has custom login logo" do
        expect(root_tenant.login_logo.url).to match(/custom_login_logo.png/)
      end
    end
  end

  describe "#login_logo?" do
    it "knows when there is a login logo" do
      expect(described_class.new(:login_logo_file_name => "image.png")).to be_login_logo
    end

    it "knows when there is no login logo" do
      expect(described_class.new).not_to be_login_logo
    end
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
      root_tenant.children.create!
    end

    it "only allows one root" do
      described_class.destroy_all
      root_tenant # create a root tenant

      expect do
        described_class.create!
      end.to raise_error
    end
  end

  context "#validate_default_tenant" do
    it "fails assigning a group with the wrong tenant" do
      tenant1 = FactoryGirl.create(:tenant)
      tenant2 = FactoryGirl.create(:tenant)
      g = FactoryGirl.create(:miq_group, :tenant => tenant1)
      expect { tenant2.update_attributes!(:default_miq_group => g) }.to raise_error
    end

    # we may want to change this in the future
    it "prevents changing default_miq_group" do
      g = FactoryGirl.create(:miq_group, :tenant => tenant)
      expect { tenant.update_attributes!(:default_miq_group => g) }.to raise_error
    end
  end

  context "#ensure_can_be_destroyed" do
    it "wouldn't delete tenant with groups associated" do
      tenant = FactoryGirl.create(:tenant)
      FactoryGirl.create(:miq_group, :tenant => tenant)
      expect { tenant.destroy! }.to raise_error
    end
  end

  describe "#description" do
    it "has description" do
      tenant.update_attributes(:description => 'very important vm')
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
    let(:self_service_role) { FactoryGirl.create(:miq_user_role, :settings => {:restrictions => {:vms => :user}}) }

    let(:brand_feature) { FactoryGirl.create(:miq_product_feature, :identifier => "edit-brand") }
    let(:admin_with_brand) { FactoryGirl.create(:miq_user_role, :name => "tenant_admin-brand-master") }

    let(:tenant1) { FactoryGirl.create(:tenant) }
    let(:tenant1_admins) do
      FactoryGirl.create(:miq_group,
                         :miq_user_role => admin_with_brand,
                         :tenant        => tenant1
                        )
    end
    let(:tenant1_users) do
      FactoryGirl.create(:miq_group,
                         :tenant        => tenant1,
                         :miq_user_role => self_service_role)
    end
    let(:admin) { FactoryGirl.create(:user, :miq_groups => [tenant1_users, tenant1_admins]) }
    let(:user1) { FactoryGirl.create(:user, :miq_groups => [tenant1_users]) }
    let(:user2) { FactoryGirl.create(:user) }

    it "has users" do
      admin; user1; user2
      expect(tenant1.users).to include(admin)
      expect(tenant1.users).to include(user1)
      expect(tenant1.users).not_to include(user2)
    end
  end

  context "#miq_ae_domains" do
    let(:t1) { FactoryGirl.create(:tenant, :name => "T1", :parent => root_tenant) }
    let(:t2) { FactoryGirl.create(:tenant, :name => "T2", :parent => root_tenant) }
    let(:dom1) { FactoryGirl.create(:miq_ae_domain, :tenant => t1, :name => 'DOM1', :priority => 20) }
    let(:dom2) { FactoryGirl.create(:miq_ae_domain, :tenant => t2, :name => 'DOM2', :priority => 40) }
    let(:t1_1) { FactoryGirl.create(:tenant, :name => 'T1_1', :domain => 'a.a.com', :parent => t1) }
    let(:t2_2) { FactoryGirl.create(:tenant, :name => 'T2_1', :domain => 'b.b.com', :parent => t2) }

    context "visibility" do
      before do
        dom1
        dom2
        FactoryGirl.create(:miq_ae_domain, :name => 'DOM15', :priority => 15,
                           :tenant_id => root_tenant.id)
        FactoryGirl.create(:miq_ae_domain, :name => 'DOM10', :priority => 10,
                           :tenant_id => root_tenant.id, :enabled => false)
        FactoryGirl.create(:miq_ae_domain, :name => 'DOM3', :priority => 3,
                           :tenant_id => t1_1.id)
        FactoryGirl.create(:miq_ae_domain, :name => 'DOM5', :priority => 7,
                           :tenant_id => t1_1.id)
        FactoryGirl.create(:miq_ae_domain, :name => 'DOM4', :priority => 5,
                           :tenant_id => t2_2.id)
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
      FactoryGirl.create(:miq_ae_domain,
                         :name      => 'non_editable',
                         :priority  => 3,
                         :tenant_id => t1_1.id,
                         :system    => true)
      expect(t1_1.any_editable_domains?).to eq(false)
    end

    it "editable domains available for current_tenant" do
      t1_1
      FactoryGirl.create(:miq_ae_domain,
                         :name      => 'editable',
                         :priority  => 3,
                         :tenant_id => t1_1.id)
      expect(t1_1.any_editable_domains?).to eq(true)
    end
  end

  describe ".set_quotas" do
    let(:tenant)  { FactoryGirl.build(:tenant, :parent => default_tenant) }

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
    let(:tenant)  { FactoryGirl.build(:tenant, :parent => default_tenant) }

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
    let(:tenant) { FactoryGirl.create(:tenant, :parent => default_tenant) }
    let(:ems) { FactoryGirl.create(:ems_vmware, :name => 'ems', :tenant => tenant) }

    let(:vm1) do
      FactoryGirl.create(
        :vm_vmware,
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryGirl.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryGirl.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
        )
      )
    end

    let(:vm2) do
      FactoryGirl.create(
        :vm_vmware,
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryGirl.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryGirl.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
        )
      )
    end

    let(:template) do
      FactoryGirl.create(
        :miq_template,
        :name                  => "test",
        :location              => "test.vmx",
        :vendor                => "vmware",
        :tenant_id             => tenant.id,
        :host_id               => 1,
        :ext_management_system => ems,
        :hardware              => FactoryGirl.create(
          :hardware,
          :memory_mb       => 1024,
          :cpu_total_cores => 1,
          :disks           => [FactoryGirl.create(:disk, :size => 12_345_678, :size_on_disk => 12_345)]
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
    let(:parent_tenant) { FactoryGirl.create(:tenant, :parent => default_tenant) }
    let(:child_tenant1) { FactoryGirl.create(:tenant, :parent => parent_tenant) }
    let(:child_tenant2) { FactoryGirl.create(:tenant, :parent => parent_tenant) }

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

      TenantQuota.any_instance.stub(:used => 2)
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
  end
end
