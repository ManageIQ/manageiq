require "spec_helper"

describe Tenant do
  let(:settings) { {} }
  let(:tenant) { described_class.new(:domain => 'x.com') }

  let(:default_tenant) do
    Tenant.seed
    described_class.default_tenant
  end

  before do
    allow(VMDB::Config).to receive(:new).with("vmdb").and_return(double(:config => settings))
  end

  describe "#default_tenant" do
    it "has a default tenant" do
      expect(default_tenant).to be
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

    it "has no logo for default_tenant" do
      expect(default_tenant.logo.url).to match(/missing/)
    end

    context "with server settings" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "uses settings value for default tenant" do
        expect(default_tenant.logo.url).to eq("/uploads/custom_logo.png")
      end

      it "overrides settings for default tenant" do
        default_tenant.update_attributes(:logo_file_name => "different.png")
        expect(default_tenant.logo.url).to eq("/uploads/different.png")
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

    it "knows there is no logo from configuration for default tenant" do
      expect(default_tenant).not_to be_logo
    end

    it "knows there is a logo overriding configuration for default tenant" do
      default_tenant.logo_file_name = "custom_logo.png"
      expect(default_tenant).to be_logo
    end

    context "#with custom_logo configuration" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "knows there is no logo ignoring settings for standard tenant" do
        expect(tenant).not_to be_logo
      end

      it "knows there is a logo from configuration for default tenant" do
        expect(default_tenant).to be_logo
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

    it "has custom content_type for default tenant" do
      expect(default_tenant.logo_content_type).to eq("image/png")
    end

    context "#with custom logo configuration" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "has custom content_type for default tenant" do
        expect(default_tenant.logo_content_type).to eq("image/png")
      end
    end
  end

  describe "#login_logo" do
    # NOTE: initializers/paperclip.rb sets up :default_login_logo

    it "has a default login image" do
      tenant.save!
      expect(tenant.login_logo.url).to match(/login-screen-logo.png/)
    end

    it "has a default login image for default tenant" do
      expect(default_tenant.login_logo.url).to match(/login-screen-logo.png/)
    end

    it "has custom login logo" do
      tenant.update_attributes(:login_logo_file_name => "custom_login_logo.png")
      expect(tenant.login_logo.url).to match(/custom_login_logo.png/)
    end

    context "with custom login logo configuration" do
      let(:settings) { {:server => {:custom_login_logo => true}} }

      it "has custom login logo" do
        expect(default_tenant.login_logo.url).to match(/custom_login_logo.png/)
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
