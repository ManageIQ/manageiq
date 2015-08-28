require "spec_helper"

describe Tenant do
  let(:settings) { {} }
  let(:tenant) { described_class.new(:domain => 'x.com', :parent => default_tenant) }

  let(:default_tenant) do
    Tenant.seed
    described_class.default_tenant
  end

  let(:root_tenant) do
    Tenant.seed
    described_class.root_tenant
  end

  before do
    stub_server_configuration(settings)
  end

  describe "#default_tenant" do
    it "has a default tenant" do
      expect(default_tenant).to be
    end
  end

  describe "#root_tenant" do
    it "has a root tenant" do
      expect(root_tenant).to be
    end

    it "can update the root_tenant" do
      root_tenant.update_attributes!(:name => 'newname')
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
      expect(root_tenant).to be_root
    end

    it "detects non root" do
      expect(tenant).not_to be_root
    end
  end

  describe "#tenant?" do
    it "detects tenant" do
      t = Tenant.new(:divisible => true)
      expect(t.tenant?).to be_true
    end

    it "detects non tenant" do
      t = Tenant.new(:divisible => false)
      expect(t.tenant?).not_to be_true
    end
  end

  describe "#project?" do
    it "detects project" do
      t = Tenant.new(:divisible => false)
      expect(t.project?).to be_true
    end

    it "detects non project" do
      t = Tenant.new(:divisible => true)
      expect(t.project?).not_to be_true
    end
  end

  describe "#display_type" do
    let(:tenant)  { FactoryGirl.build(:tenant, :parent => default_tenant) }
    let(:project) { FactoryGirl.build(:tenant, :parent => default_tenant, :divisible => false) }

    it "detects Tenant" do
      expect(tenant.display_type).to eql  'Tenant'
      expect(project.display_type).not_to eql  'Tenant'
    end

    it "detects Project" do
      expect(project.display_type).to eql 'Project'
      expect(tenant.display_type).not_to eql 'Project'
    end
  end

  it ".all_tenants" do
    FactoryGirl.create(:tenant, :parent => root_tenant)
    FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)

    expect(Tenant.all_tenants.count).to eql 2 # The one we created + the default tenant
  end

  it ".all_projects" do
    FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)
    FactoryGirl.create(:tenant, :parent => root_tenant, :divisible => false)

    expect(Tenant.all_projects.count).to eql 2 # Should not return the default tenant
  end

  describe "#set_quotas" do
    let(:tenant)  {FactoryGirl.build(:tenant, :parent => default_tenant)}

    it "can set quotas" do
      tenant.set_quotas(:vms_allocated => {:value => 20})

      expect(tenant.tenant_quotas.length).to eql 1
    end
  end

  describe "#get_quotas" do
    let(:tenant)  {FactoryGirl.build(:tenant, :parent => default_tenant)}

    it "can get quotas" do
      expect(tenant.get_quotas).not_to be_empty
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
    let(:settings) { {:server => {:company => "settings"}} }

    it "has default name" do
      expect(tenant.name).to eq("My Company")
    end

    it "has custom name" do
      tenant.name = "custom"
      expect(tenant.name).to eq("custom")
    end

    it "doesnt read settings for regular tenant" do
      tenant.name = nil
      expect(tenant.name).to be_nil
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

    context "for default tenant" do
      it "reads settings" do
        expect(root_tenant[:name]).to be_nil
        expect(root_tenant.name).to eq("settings")
      end

      it "has custom name" do
        root_tenant.name = "custom"
        expect(root_tenant.name).to eq("custom")
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

    context "with server settings" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "uses settings value for root_tenant" do
        expect(root_tenant.logo.url).to eq("/uploads/custom_logo.png")
      end

      it "overrides settings for default tenant" do
        root_tenant.update_attributes(:logo_file_name => "different.png")
        expect(root_tenant.logo.url).to eq("/uploads/different.png")
      end

      # would prefer if url was nil, but this is how paperclip works
      it "does not use settings for regular tenant" do
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

    it "knows there is no logo from configuration for root_tenant" do
      expect(root_tenant).not_to be_logo
    end

    it "knows there is a logo overriding configuration for root_tenant" do
      root_tenant.logo_file_name = "custom_logo.png"
      expect(root_tenant).to be_logo
    end

    context "#with custom_logo configuration" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "knows there is no logo ignoring settings for standard tenant" do
        expect(tenant).not_to be_logo
      end

      it "knows there is a logo from configuration for root_tenant" do
        expect(root_tenant).to be_logo
      end

      # don't know how to override custom_logo configuration for default tenant
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

    it "has custom content_type for root_tenant" do
      expect(root_tenant.logo_content_type).to eq("image/png")
    end

    context "#with custom logo configuration" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "has custom content_type for root_tenant" do
        expect(root_tenant.logo_content_type).to eq("image/png")
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
      let(:settings) { {:server => {:custom_login_logo => true}} }

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
      expect(described_class.create(:domain => "  ").domain).to be_nil
    end

    it "nulls out blank subdomain" do
      expect(described_class.create(:subdomain => "  ").domain).to be_nil
    end
  end

  context "#validate_only_one_root" do
    it "allows child tenants" do
      root_tenant.children.create!
    end

    it "only allows one root" do
      described_class.destroy_all
      described_class.seed

      expect {
        described_class.create!
      }.to raise_error
    end
  end

  describe "#description" do
    it "has description" do
      tenant.update_attributes(:description => 'very important vm')
      expect(tenant.description).not_to be_nil
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
                         :tenant_owner  => tenant1
                         )
    end
    let(:tenant1_users) do
      FactoryGirl.create(:miq_group,
                         :tenant_owner  => tenant1,
                         :miq_user_role => self_service_role)
    end
    let(:admin) { FactoryGirl.create(:user, :userid => 'admin', :miq_groups => [tenant1_users, tenant1_admins]) }
    let(:user1) { FactoryGirl.create(:user, :userid => 'user',  :miq_groups => [tenant1_users]) }
    let(:user2) { FactoryGirl.create(:user, :userid => 'user2') }

    it "has users" do
      admin ; user1 ; user2
      expect(tenant1.users).to include(admin)
      expect(tenant1.users).to include(user1)
      expect(tenant1.users).not_to include(user2)
    end
  end

  context "#miq_ae_domains" do
    let(:t1) { FactoryGirl.create(:tenant, :name => "T1", :parent => root_tenant) }
    let(:t2) { FactoryGirl.create(:tenant, :name => "T2", :parent => root_tenant) }
    let(:dom1) { FactoryGirl.create(:miq_ae_domain, :tenant => t1) }
    let(:dom2) { FactoryGirl.create(:miq_ae_domain, :tenant => t2) }

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
  end
end
