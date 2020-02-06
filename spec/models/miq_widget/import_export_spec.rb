RSpec.describe MiqWidget::ImportExport do
  context "legacy tests" do
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

  describe "#import_from_hash" do
    context "when the widget given is nil" do
      let(:widget) { nil }

      it "raises an error" do
        expect { MiqWidget.import_from_hash(widget) }.to raise_error("No Widget to Import")
      end
    end

    context "when the widget given is not nil" do
      let(:widget) { "a non nil widget" }
      let(:widget_import_service) { double("WidgetImportService") }

      before do
        allow(WidgetImportService).to receive(:new).and_return(widget_import_service)
      end

      it "delegates to the widget import service" do
        expect(widget_import_service).to receive(:import_widget_from_hash).with(widget)
        MiqWidget.import_from_hash(widget)
      end
    end
  end
end
