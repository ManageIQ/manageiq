require 'spec_helper'

describe TenantQuota do
  let(:tenant) { FactoryGirl.create(:tenant, :parent => root_tenant) }

  let(:root_tenant) do
    MiqRegion.seed
    Tenant.seed
    Tenant.root_tenant
  end

  describe "#valid?" do
    it "rejects invalid name" do
      expect(described_class.new(:name => "XXX")).not_to be_valid
    end

    it "rejects missing value" do
      expect(described_class.new(:name => :cpu_allocated, :unit => "mhz")).not_to be_valid
    end

    it "defaults missing unit" do
      expect(described_class.new(:name => :cpu_allocated, :value => 4096)).to be_valid
    end

    it "accepts valid quota" do
      expect(described_class.new(:name => :cpu_allocated, :unit => "mhz", :value => 4096)).to be_valid
    end

    it "accepts string name" do
      expect(described_class.new(:name => "cpu_allocated", :unit => "mhz", :value => 4096)).to be_valid
    end
  end

  describe "#format" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).format).to eq("mhz")
    end
  end

  describe "#default_unit" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).default_unit).to eq("mhz")
    end
  end
end
