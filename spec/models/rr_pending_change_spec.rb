describe RrPendingChange do
  it ".table_name" do
    expect(described_class.table_name).to eq("rr#{MiqRegion.my_region_number}_pending_changes")
  end

  it ".table_exists?" do
    expect(described_class.table_exists?).to be_falsey
  end

  it ".last_id" do
    expect { described_class.last_id }.to raise_error(ActiveRecord::StatementInvalid)
  end

  context ".for_region_number" do
    it ".table_name" do
      described_class.for_region_number(1000) do
        expect(described_class.table_name).to eq("rr1000_pending_changes")
      end
    end

    it ".table_exists?" do
      described_class.for_region_number(1000) do
        expect(described_class.table_exists?).to be_falsey
      end
    end

    it ".last_id" do
      described_class.for_region_number(1000) do
        expect { described_class.last_id }.to raise_error(ActiveRecord::StatementInvalid)
      end
    end
  end

  describe ".backlog_details" do
    require 'active_support/testing/stream'
    include ActiveSupport::Testing::Stream

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
