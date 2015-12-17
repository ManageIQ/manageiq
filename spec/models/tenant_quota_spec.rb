require 'spec_helper'

describe TenantQuota do
  let(:tenant) { FactoryGirl.create(:tenant) }

  describe "#valid?" do
    it "rejects invalid name" do
      expect(described_class.new(:name => "XXX")).not_to be_valid
    end

    it "rejects missing value" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum")).not_to be_valid
    end

    it "rejects 0 warn_value" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :value => 1, :warn_value => 0)).not_to be_valid
    end

    it "defaults missing unit" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :value => 16)).to be_valid
    end

    it "accepts valid quota" do
      expect(described_class.new(:tenant => tenant, :name => :cpu_allocated, :unit => "fixnum", :value => 16)).to be_valid
    end

    it "accepts string name" do
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :unit => "fixnum", :value => 16)).to be_valid
    end
  end

  describe ".check_for_over_allocation" do
    let(:child_tenant) { FactoryGirl.create(:tenant) }
    let(:grandchild_tenant1) { FactoryGirl.create(:tenant, :parent => child_tenant) }
    let(:grandchild_tenant2) { FactoryGirl.create(:tenant, :parent => child_tenant) }
    let(:great_grandchild_tenant) { FactoryGirl.create(:tenant, :parent => grandchild_tenant1) }

    before do
      child_tenant
      grandchild_tenant1
      grandchild_tenant2
    end

    it "root tenant has unlimited quota" do
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :value => 1000)).to be_valid
    end

    it "child of root tenant also has unlimited quota" do
      described_class.create(:tenant => tenant, :name => "cpu_allocated", :value => 10)
      expect(described_class.new(:tenant => child_tenant, :name => "cpu_allocated", :value => 1000)).to be_valid
    end

    context "grandchild tenant" do
      it "cannot have less quota than the amount given to children" do
        described_class.create(:tenant => great_grandchild_tenant, :name => "cpu_allocated", :value => 10)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 9)).not_to be_valid
      end

      it "cannot have less quota than the amount that has already been used" do
        nq = described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)
        nq.stub(:used => 2)
        expect(nq).not_to be_valid
      end
    end

    context "grandchild tenant, parent with infinity(undefined) quota" do
      it "can have unlimited quota" do
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 1000)).to be_valid
      end
    end

    context "grandchild tenant, parent over allocated" do
      it "cannot have more quota than the parent has available to allocate" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 6)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has used up its available" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)

        described_class.any_instance.stub(:used => 5)
        expect(described_class.new(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has allocated it to a different child" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        described_class.create!(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 5)
        expect(described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "cannot have more quota than the parent has available to allocate when parent has used and has allocated it to a different child" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 5)
        described_class.create!(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 3)

        described_class.any_instance.stub(:used => 2)
        expect(described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)).not_to be_valid
      end

      it "can give quota that the parent has available to allocate when parent used and allocated is less than the total quota of the parent" do
        described_class.create!(:tenant => child_tenant, :name => "cpu_allocated", :value => 10)
        described_class.create(:tenant => grandchild_tenant1, :name => "cpu_allocated", :value => 3)

        nq = described_class.new(:tenant => grandchild_tenant2, :name => "cpu_allocated", :value => 1)
        nq.stub(:used => 0)
        described_class.any_instance.stub(:used => 6)
        expect(nq).to be_valid
      end
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
      expect(described_class.new(:tenant => tenant, :name => "cpu_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Virtual CPUs"
      )
    end

    it "has vms_allocated attributes" do
      expect(described_class.new(:tenant => tenant, :name => "vms_allocated", :value => 20).tap(&:valid?).quota_hash).to eq(
        :unit          => "fixnum",
        :value         => 20.0,
        :warn_value    => nil,
        :format        => "general_number_precision_0",
        :text_modifier => "Count",
        :description   => "Allocated Number of Virtual Machines"
      )
    end

    it "has mem_allocated attributes" do
      expect(described_class.new(:tenant => tenant, :name => "mem_allocated", :value => 4096).tap(&:valid?).quota_hash).to eq(
        :unit          => "bytes",
        :value         => 4096.0,
        :warn_value    => nil,
        :format        => "gigabytes_human",
        :text_modifier => "GB",
        :description   => "Allocated Memory in GB"
      )
    end

    it "has nil attributes" do
      expect(described_class.new(:tenant => tenant, :name => "storage_allocated").tap(&:valid?).quota_hash).to eq(
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
    let(:tenant2) { FactoryGirl.create(:tenant) }

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
