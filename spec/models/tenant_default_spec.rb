require "spec_helper"

describe TenantDefault do
  let(:settings) { {} }
  let(:tenant) { described_class.new }
  before do
    allow(VMDB::Config).to receive(:new).with("vmdb").and_return(double(:config => settings))
  end

  describe "#default?" do
    it "is default" do
      expect(tenant).to be_default
    end
  end

  describe "#default?" do
    it "is using settings" do
      expect(tenant).to be_settings
    end
  end

  describe "#logo (with custom logo)" do
    let(:settings) { {:server => {:custom_logo => true}} }

    # for now, we are hard coding to uploads directory
    it "has the hardcoded logo url" do
      expect(tenant.logo.url).to eq("/uploads/custom_logo.png")
    end

    it "points to the hardcoded logo file" do
      expect(tenant.logo.path).to eq(Rails.root.join("public/uploads/custom_logo.png").to_s)
    end
  end

  describe "#logo?" do
    it "knows when there is no logo" do
      expect(tenant).not_to be_logo
    end

    context "with custom logo" do
      let(:settings) { {:server => {:custom_logo => true}} }

      it "knows when there a logo" do
        expect(tenant).to be_logo
      end
    end
  end

  describe "#login_logo" do
    # NOTE: initializers/paperclip.rb sets up :default_login_logo

    it "has a default login image" do
      expect(tenant.login_logo.url).to match(/login-screen-logo.png/)
    end

    context "with custom login logo" do
      let(:settings) { {:server => {:custom_login_logo => true}} }

      it "has custom login logo" do
        expect(tenant.login_logo.url).to match(/custom_login_logo.png/)
      end
    end
  end

  describe "#login_logo?" do
    it "knows when there is no login logo" do
      expect(tenant).not_to be_login_logo
    end

    context "with custom login logo" do
      let(:settings) { {:server => {:custom_login_logo => true}} }

      it "knows when there is a login logo" do
        expect(tenant).to be_login_logo
      end
    end
  end

  context "temporary names" do
    let(:settings) do
      {
        :server => {
          :company => "company",
          :name    => "vmdb",
        }
      }
    end
    it "supports legacy vmdb_name" do
      expect(described_class.new.customer_name).to eq('company')
    end

    it "supports legacy appliance_name" do
      expect(described_class.new.vmdb_name).to eq('vmdb')
    end
  end
end
