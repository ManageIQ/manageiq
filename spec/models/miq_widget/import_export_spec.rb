require "spec_helper"

describe MiqWidget::ImportExport do
  before do
    MiqReport.seed_report("Vendor and Guest OS")
    @widget_report_vendor_and_guest_os = MiqWidget.sync_from_hash(YAML.load('
      description: report_vendor_and_guest_os
      title: Vendor and Guest OS
      content_type: report
      options:
        :col_order:
          - name
          - vendor
        :row_count: 10
      visibility:
        :roles:
        - _ALL_
      resource_name: Vendor and Guest OS
      resource_type: MiqReport
      enabled: true
      read_only: true
    '))
  end

  context "#export_to_array" do
    subject { @widget_report_vendor_and_guest_os.export_to_array.first }

    it "MiqWidget" do
      subject["MiqWidget"].should_not be_empty
    end

    it "MiqReportContent" do
      report = MiqReport.where(:name => "Vendor and Guest OS").first
      subject["MiqWidget"]["MiqReportContent"].should == report.export_to_array
    end

    it "no id" do
      subject["MiqWidget"]["id"].should be_nil
    end

    it "no created_at" do
      subject["MiqWidget"]["created_at"].should be_nil
    end

    it "no updated_at" do
      subject["MiqWidget"]["updated_at"].should be_nil
    end
  end
end
