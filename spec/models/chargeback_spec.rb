describe Chargeback do
  let(:rpt) { MiqReport.new(:db => chargeback_model.name, :headers => [], :col_formats => []) }
  let(:chargeback_model) { ChargebackVm }

  # called from ReportController::Reports::Editor
  # must be called on a subclass of Chargeback
  describe ".set_chargeback_report_options" do
    context "with ChargebackVm" do
      let(:chargeback_model) { ChargebackVm }
      it "groups by date-only" do
        chargeback_model.set_chargeback_report_options(rpt, "date-only", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range])
        expect(rpt.col_order).to eq(%w[display_range])
        expect(rpt.sortby).to eq(%w[start_date])
      end

      it "groups by project" do
        chargeback_model.set_chargeback_report_options(rpt, "project", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range project_name])
        expect(rpt.col_order).to eq(%w[project_name display_range])
        expect(rpt.sortby).to eq(%w[project_name start_date])
      end

      it "groups by other" do
        chargeback_model.set_chargeback_report_options(rpt, "xx", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range vm_name])
        expect(rpt.col_order).to eq(%w[vm_name display_range])
        expect(rpt.sortby).to eq(%w[vm_name start_date])
      end
    end

    context "with ChargebackContainerProject" do
      let(:chargeback_model) { ChargebackContainerProject }
      it "groups by date-only" do
        chargeback_model.set_chargeback_report_options(rpt, "date-only", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range])
        expect(rpt.col_order).to eq(%w[display_range])
        expect(rpt.sortby).to eq(%w[start_date])
      end

      it "groups by project" do
        chargeback_model.set_chargeback_report_options(rpt, "project", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range project_name])
        expect(rpt.col_order).to eq(%w[project_name display_range])
        expect(rpt.sortby).to eq(%w[project_name start_date])
      end

      it "groups by other" do
        chargeback_model.set_chargeback_report_options(rpt, "xx", "Tag", "Group By", "UTF")

        expect(rpt.cols).to eq(%w[start_date display_range project_name])
        expect(rpt.col_order).to eq(%w[project_name display_range])
        expect(rpt.sortby).to eq(%w[project_name start_date])
      end
    end
  end
end
