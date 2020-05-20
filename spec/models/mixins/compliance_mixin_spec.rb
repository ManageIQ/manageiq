RSpec.describe ComplianceMixin do
  include Spec::Support::ArelHelper

  let(:host)           { FactoryBot.create(:host) }
  let(:new_timestamp)  { 2.months.ago.change(:usec => 0) }
  let(:old_timestamp)  { 4.months.ago.change(:usec => 0) }
  let(:new_compliance) { FactoryBot.create(:compliance, :resource => host, :timestamp => new_timestamp, :compliant => false) }
  let(:old_compliance) { FactoryBot.create(:compliance, :resource => host, :timestamp => old_timestamp) }
  let(:compliances)    { [old_compliance, new_compliance] }

  describe "#last_compliance" do
    it "uses the most recent value" do
      compliances
      expect(host.last_compliance.timestamp).to eq(new_timestamp)
    end
  end

  describe "#last_compliance_status" do
    context "with no compliances" do
      it "is nil with sql" do
        host
        expect(virtual_column_sql_value(Host, "last_compliance_status")).to be_nil
      end

      it "is nil with ruby" do
        expect(host.last_compliance_status).to be_nil
      end
    end

    context "with compliances" do
      before { compliances }

      it "has the most recent timestamp with sql" do
        h = Host.select(:id, :last_compliance_status).first

        expect do
          expect(h.last_compliance_status).to eq(false)
        end.to match_query_limit_of(0)
        expect(h.association(:last_compliance)).not_to be_loaded
      end

      it "has the most recent timestamp with ruby" do
        h = Host.first # clean host record

        expect(h.last_compliance_status).to eq(false)
        expect(h.association(:last_compliance)).to be_loaded
      end
    end
  end

  describe "#last_compliance_conditions" do
    context "with no compliances" do
      it "returns an empty list" do
        expect(host.last_compliance_conditions).to be_empty
      end
    end

    context "with compliances" do
      let(:last_compliance) { FactoryBot.create(:compliance, :with_details_and_conditions, :resource => host, :timestamp => Time.now, :compliant => false) }

      before do
        compliances
        last_compliance
      end

      it "returns an array of condition objects" do
        expect(host.last_compliance_conditions.length).to eq(2)
      end
    end
  end

  describe "#last_compliance_condition_expressions" do
    context "with no compliances" do
      it "returns an empty list" do
        expect(host.last_compliance_condition_expressions).to be_empty
      end
    end

    context "with compliances" do
      let(:last_compliance) { FactoryBot.create(:compliance, :with_details_and_conditions, :resource => host, :timestamp => Time.now, :compliant => false) }

      before do
        compliances
        last_compliance
      end

      it "returns an array of condition expressions" do
        expect(host.last_compliance_condition_expressions).to eq(["VM and Instance : Number of CPUs >= 2", "VM and Instance : Number of CPUs >= 2"])
      end
    end
  end
end
