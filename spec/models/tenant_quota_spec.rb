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

  describe "#quota_hash" do
    it "has cpu_allocated attributes" do
      expect(described_class.new(:name => "cpu_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "mhz",
        :value         => 4096.0,
        :format        => "mhz",
        :text_modifier => "Mhz",
        :description   => "Allocated CPU in Mhz"
      )
    end

    it "has vms_allocated attributes" do
      expect(described_class.new(:name => "vms_allocated", :value => 20).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 20.0,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Number of Virtual Machines"
      )
    end

    it "has mem_allocated attributes" do
      expect(described_class.new(:name => "mem_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => 4096.0,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Memory in GB"
      )
    end

    it "has nil attributes" do
      expect(described_class.new(:name => "storage_allocated").tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Storage in GB"
      )
    end
  end
end
