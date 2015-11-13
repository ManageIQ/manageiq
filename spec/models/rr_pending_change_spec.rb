require "spec_helper"

describe RrPendingChange do
  it ".table_name" do
    described_class.table_name.should == "rr#{MiqRegion.my_region_number}_pending_changes"
  end

  it ".table_exists?" do
    described_class.table_exists?.should be_false
  end

  it ".last_id" do
    -> { described_class.last_id }.should raise_error
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
        -> { described_class.last_id }.should raise_error
      end
    end
  end

  describe ".backlog_details" do
    it "returns the correct counts" do
      MiqRegion.seed
      region = MiqRegion.my_region_number

      silence_stream($stdout) do
        ActiveRecord::Schema.define do
          create_table "rr#{region}_pending_changes" do |t|
            t.string    :change_table
            t.string    :change_key
            t.string    :change_new_key
            t.string    :change_type
            t.timestamp :change_time
          end
        end
      end
      FactoryGirl.create(:rr_pending_change, :change_table => "users")
      FactoryGirl.create_list(:rr_pending_change, 2, :change_table => "miq_servers")
      expect(described_class.backlog_details).to eq("miq_servers" => 2, "users" => 1)
    end
  end
end
