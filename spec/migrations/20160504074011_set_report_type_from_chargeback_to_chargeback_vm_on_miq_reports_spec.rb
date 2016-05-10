require_migration

describe SetReportTypeFromChargebackToChargebackVmOnMiqReports do
  let(:miq_report_stub) { migration_stub(:MiqReport) }

  migration_context :up do
    it "sets with db = ChargeBack to ChargebackVm for column db and db_option[:rpt_type]" do
      db_options = {}
      db_options[:rpt_type] = described_class::CHARGEBACK_REPORT_DB_MODEL

      miq_reports = Array.new(2) do
        miq_report_stub.create!(:db => described_class::CHARGEBACK_REPORT_DB_MODEL, :db_options => db_options)
      end

      migrate

      miq_reports.each do |miq_report|
        miq_report.reload
        expect(miq_report.db).to eq(described_class::CHARGEBACK_VM_REPORT_DB_MODEL)
        expect(miq_report.db_options[:rpt_type]).to eq(described_class::CHARGEBACK_VM_REPORT_DB_MODEL)
      end
    end
  end

  migration_context :down do
    it "sets with db = ChargeBackVm to Chargeback for column db and db_option[:rpt_type]" do
      db_options = {}
      db_options[:rpt_type] = described_class::CHARGEBACK_VM_REPORT_DB_MODEL

      miq_reports = Array.new(2) do
        miq_report_stub.create!(:db => described_class::CHARGEBACK_VM_REPORT_DB_MODEL, :db_options => db_options)
      end

      migrate

      miq_reports.each do |miq_report|
        miq_report.reload
        expect(miq_report.db).to eq(described_class::CHARGEBACK_REPORT_DB_MODEL)
        expect(miq_report.db_options[:rpt_type]).to eq(described_class::CHARGEBACK_REPORT_DB_MODEL.downcase)
      end
    end
  end
end
