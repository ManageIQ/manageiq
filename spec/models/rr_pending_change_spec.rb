require "spec_helper"

describe RrPendingChange do
  before(:each) do
    MiqRegion.seed
  end

  it ".table_name" do
    described_class.table_name.should == "rr#{MiqRegion.my_region_number}_pending_changes"
  end

  it ".table_exists?" do
    described_class.table_exists?.should be_false
  end

  it ".last_id" do
    lambda { described_class.last_id }.should raise_error
  end

  context ".for_region_number" do
    it ".table_name" do
      described_class.for_region_number(1000) do
        described_class.table_name.should == "rr1000_pending_changes"
      end
    end

    it ".table_exists?" do
      described_class.for_region_number(1000) do
        described_class.table_exists?.should be_false
      end
    end

    it ".last_id" do
      described_class.for_region_number(1000) do
        lambda { described_class.last_id }.should raise_error
      end
    end
  end
end
