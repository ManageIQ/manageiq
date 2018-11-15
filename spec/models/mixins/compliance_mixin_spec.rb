describe ComplianceMixin do
  include Spec::Support::ArelHelper

  let(:host)           { FactoryGirl.create(:host) }
  let(:new_timestamp)  { 2.months.ago.change(:usec => 0) }
  let(:old_timestamp)  { 4.months.ago.change(:usec => 0) }
  let(:new_compliance) { FactoryGirl.create(:compliance, :resource => host, :timestamp => new_timestamp, :compliant => false) }
  let(:old_compliance) { FactoryGirl.create(:compliance, :resource => host, :timestamp => old_timestamp) }
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
end
