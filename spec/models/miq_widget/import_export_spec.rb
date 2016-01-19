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
      expect(subject["MiqWidget"]).not_to be_empty
    end

    it "MiqReportContent" do
      report = MiqReport.where(:name => "Vendor and Guest OS").first
      expect(subject["MiqWidget"]["MiqReportContent"]).to eq(report.export_to_array)
    end

    it "no id" do
      expect(subject["MiqWidget"]["id"]).to be_nil
    end

    it "no created_at" do
      expect(subject["MiqWidget"]["created_at"]).to be_nil
    end

    it "no updated_at" do
      expect(subject["MiqWidget"]["updated_at"]).to be_nil
    end
  end
end
