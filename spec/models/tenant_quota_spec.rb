require 'spec_helper'

describe TenantQuota do
  let(:tenant) { FactoryGirl.create(:tenant, :parent => root_tenant) }

  let(:root_tenant) do
    EvmSpecHelper.create_root_tenant
  end

  describe "#valid?" do
    it "rejects invalid name" do
      expect(described_class.new(:name => "XXX")).not_to be_valid
    end

    it "rejects missing value" do
      expect(described_class.new(:name => :cpu_allocated, :unit => "fixnum")).not_to be_valid
    end

    it "rejects 0 warn_value" do
      expect(described_class.new(:name => :cpu_allocated, :value => 1, :warn_value => 0)).not_to be_valid
    end

    it "defaults missing unit" do
      expect(described_class.new(:name => :cpu_allocated, :value => 16)).to be_valid
    end

    it "accepts valid quota" do
      expect(described_class.new(:name => :cpu_allocated, :unit => "fixnum", :value => 16)).to be_valid
    end

    it "accepts string name" do
      expect(described_class.new(:name => "cpu_allocated", :unit => "fixnum", :value => 16)).to be_valid
    end
  end

  describe "#format" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).format).to eq("general_number_precision_0")
    end
  end

  describe "#default_unit" do
    it "has cpu" do
      expect(FactoryGirl.build(:tenant_quota_cpu).default_unit).to eq("fixnum")
    end
  end

  describe "#quota_hash" do
    it "has cpu_allocated attributes" do
      expect(described_class.new(:name => "cpu_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Virtual CPUs"
      )
    end

    it "has vms_allocated attributes" do
      expect(described_class.new(:name => "vms_allocated", :value => 20).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 20.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Number of Virtual Machines"
      )
    end

    it "has mem_allocated attributes" do
      expect(described_class.new(:name => "mem_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Memory in GB"
      )
    end

    it "has nil attributes" do
      expect(described_class.new(:name => "storage_allocated").tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => nil,
        :warn_value    => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Storage in GB"
      )
    end
  end

  describe ".destroy_missing" do
    let(:tenant2) { FactoryGirl.create(:tenant, :parent => root_tenant) }

    it "removes extra quotas only from object in question" do
      tenant.tenant_quotas.create(:name => :vms_allocated, :value => 20)
      tenant.tenant_quotas.create(:name => :mem_allocated, :value => 4096)
      tenant2.tenant_quotas.create(:name => :cpu_allocated, :value => 8)

      tenant.tenant_quotas.destroy_missing([:vms_allocated])
      expect(tenant.tenant_quotas.count).to eq(1)
      expect(tenant2.tenant_quotas.count).to eq(1)
    end
  end
end
