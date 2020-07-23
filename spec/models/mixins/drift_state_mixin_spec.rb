RSpec.describe DriftStateMixin do
  include Spec::Support::ArelHelper

  let(:host) { FactoryBot.create(:host) }

  let(:drift_states) do
    [
      FactoryBot.create(:drift_state, :resource => host, :timestamp => recent_timestamp, :data => "bogus"),
      FactoryBot.create(:drift_state, :resource => host, :timestamp => old_timestamp, :data => "bogus")
    ]
  end

  let(:recent_timestamp) { 2.months.ago.change(:usec => 0) }
  let(:old_timestamp) { 4.months.ago.change(:usec => 0) }

  describe "#first_drift_state" do
    it "uses the most recent value" do
      drift_states
      expect(host.last_drift_state.timestamp).to eq(recent_timestamp)
    end
  end

  describe "#last_drift_state" do
    it "uses the least recent value" do
      drift_states
      expect(host.first_drift_state.timestamp).to eq(old_timestamp)
    end
  end

  describe "#last_drift_state_timestamp" do
    context "with no drift_state records" do
      before { host }

      it "has a nil value with sql" do
        expect(virtual_column_sql_value(Host, "last_drift_state_timestamp")).to be_nil
      end

      it "has a nil value with ruby" do
        expect(host.last_drift_state_timestamp).to be_nil
      end
    end

    context "with drift_state records" do
      before { drift_states }

      it "has the most recent timestamp with sql" do
        h = Host.select(:id, :last_drift_state_timestamp).first
        expect do
          expect(h.last_drift_state_timestamp).to eq(recent_timestamp)
        end.to_not make_database_queries
        expect(h.association(:last_drift_state)).not_to be_loaded
        expect(h.association(:last_drift_state_timestamp_rec)).not_to be_loaded
      end

      it "has the most recent timestamp with ruby" do
        h = Host.first # want a clean host record
        expect(h.last_drift_state_timestamp).to eq(recent_timestamp)
        expect(h.association(:last_drift_state)).not_to be_loaded
        expect(h.association(:last_drift_state_timestamp_rec)).to be_loaded
      end
    end
  end

  # ems_cluster and host specific
  describe "#last_scan_on" do
    context "with no drift_state records" do
      before { host }

      it "has a nil value with sql" do
        expect(virtual_column_sql_value(Host, "last_scan_on")).to be_nil
      end

      it "has a nil value with ruby" do
        expect(host.last_scan_on).to be_nil
      end
    end

    context "with drift_state records" do
      before { drift_states }

      it "has the most recent timestamp with sql" do
        h = Host.select(:id, :last_scan_on).first
        expect do
          expect(h.last_scan_on).to eq(recent_timestamp)
        end.to_not make_database_queries
        expect(h.association(:last_drift_state)).not_to be_loaded
        expect(h.association(:last_drift_state_timestamp_rec)).not_to be_loaded
      end

      it "has the most recent timestamp with ruby" do
        h = Host.first # want a clean host record
        expect do
          expect(h.last_scan_on).to eq(recent_timestamp)
        end.to make_database_queries(:count => 1)
        expect(h.association(:last_drift_state)).not_to be_loaded
        expect(h.association(:last_drift_state_timestamp_rec)).to be_loaded
      end
    end
  end
end
