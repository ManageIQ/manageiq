require "spec_helper"

describe Tenant do
  describe "#default_tenant" do
    before do
      Tenant.seed
    end

    it "has a default tenant" do
      expect(described_class.default_tenant).to be
    end
  end

  describe "#default?" do
    before do
      Tenant.seed
    end

    it "is default" do
      expect(described_class.default_tenant).to be_default
    end

    it "is not default" do
      expect(FactoryGirl.build(:tenant, :domain => 'x.com')).not_to be_default
    end
  end

  describe "#logo" do
    let(:tenant) { FactoryGirl.create(:tenant, :logo_file_name => "custom_logo.png") }

    # NOTE: this currently returns a bogus url.
    # it { expect(described_class.create.logo.url).to be_nil }

    # for now, we are hard coding to uploads directory
    it "has the hardcoded logo url" do
      expect(tenant.logo.url).to eq("/uploads/custom_logo.png")
    end

    it "points to the hardcoded logo file" do
      expect(tenant.logo.path).to eq(Rails.root.join("public/uploads/custom_logo.png").to_s)
    end
  end

  describe "#logo?" do
    it "knows when there is a logo" do
      expect(described_class.new(:logo_file_name => "custom_logo.png")).to be_logo
    end

    it "knows when there is no logo" do
      expect(described_class.new).not_to be_logo
    end
  end

  describe "#login_logo" do
    # NOTE: initializers/paperclip.rb sets up :default_login_logo

    let(:tenant) { FactoryGirl.create(:tenant) }

    it "has a default login image" do
      expect(tenant.login_logo.url).to match(/login-screen-logo.png/)
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

  context "temporary names" do
    it "supports legacy vmdb_name" do
      expect(described_class.new(:company_name => 'company').customer_name).to eq('company')
    end

    it "supports legacy appliance_name" do
      expect(described_class.new(:appliance_name => 'vmdb').vmdb_name).to eq('vmdb')
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
end
