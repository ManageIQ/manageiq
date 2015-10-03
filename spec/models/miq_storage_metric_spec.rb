require "spec_helper"

describe MiqStorageMetric do
  let(:time) { Time.utc(2013, 4, 22, 8, 31) }

  context ".purge_date" do
    it "using Fixnum" do
      stub_server_configuration(:storage => {:metrics_history => {:token => 20}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.days.ago.utc
      end
    end

    it "using Time Unit days" do
      stub_server_configuration(:storage => {:metrics_history => {:token => "20.days"}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.days.ago.utc
      end
    end

    it "using Time Unit minutes" do
      stub_server_configuration(:storage => {:metrics_history => {:token => "20.minutes"}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq 20.minutes.ago.utc
      end
    end

    it "handles nill" do
      stub_server_configuration(:storage => {:metrics_history => {:token => nil}})
      Timecop.freeze(time) do
        expect(described_class.purge_date(:token)).to eq nil
      end
    end
  end
end
