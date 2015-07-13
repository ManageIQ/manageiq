require "spec_helper"

describe Tenant do
  context "#default_tenant" do
    before do
      Tenant.seed
    end

    it "has a default tenant" do
      expect(described_class.default_tenant).to be
    end
  end

  context "#logo" do
    let(:tenant) { FactoryGirl.create(:tenant, :logo_file_name => "image.png") }

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

  context "#logo?" do
    it "knows when there is a logo" do
      expect(described_class.new(:logo_file_name => "image.png")).to be_logo
    end

    it "knows when there is no logo" do
      expect(described_class.new).not_to be_logo
    end
  end

  context "#login_logo" do
    # NOTE: initializers/paperclip.rb sets up :default_login_logo

    let(:tenant) { FactoryGirl.create(:tenant) }

    it "has a default login image" do
      expect(tenant.login_logo.url).to match(/login-screen-logo.png/)
    end
  end

  context "#login_logo?" do
    it "knows when there is a login logo" do
      expect(described_class.new(:login_logo_file_name => "image.png")).to be_login_logo
    end

    it "knows when there is no login logo" do
      expect(described_class.new).not_to be_login_logo
    end
  end

  context "#nil_blanks" do
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
end
