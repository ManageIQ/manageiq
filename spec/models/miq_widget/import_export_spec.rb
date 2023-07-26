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

  describe ".import" do
    before { EvmSpecHelper.local_guid_miq_server_zone }

    it "imports" do
      fd = StringIO.new(<<~YAML)
        - MiqWidget:
            guid: 7e1fc241-5219-4ee2-8a8f-c4c2fdd587de
            description: chart_guest_os_information_any_os
            title: Guest OS Information
            content_type: chart
            options:
              :timezone_matters: false
            visibility:
              :roles:
              - _ALL_
            user_id:
            resource_id: 21
            resource_type: MiqReport
            enabled: true
            read_only: true
            MiqReportContent:
            - MiqReport:
                title: Guest OS Information - any OS
                rpt_group: Configuration Management - Virtual Machines
                rpt_type: Default
                priority: 59
                db: Vm
                cols:
                - name
                - vendor_display
                - os_image_name
                include:
                  operating_system:
                    columns:
                    - product_name
                    - service_pack
                    - version
                    - build_number
                    - product_key
                    - productid
                col_order:
                - operating_system.product_name
                - operating_system.service_pack
                - name
                - vendor_display
                - os_image_name
                - operating_system.version
                - operating_system.build_number
                - operating_system.product_key
                - operating_system.productid
                headers:
                - Guest OS
                - OS Service Pack
                - VM Name
                - Vendor
                - OS Name
                - OS Version
                - OS Build Number
                - OS Product Key
                - OS Productid
                conditions:
                order: Ascending
                sortby:
                - operating_system.product_name
                - operating_system.service_pack
                group: c
                graph:
                  :type: Pie
                  :count: 10
                  :other: true
                dims: 1
                filename: 100_Configuration Management - Virtual Machines/059_Guest OS Information
                  (any OS).yaml
                file_mtime: !ruby/object:ActiveSupport::TimeWithZone
                  utc: 2023-06-06 20:07:17.000000000 Z
                  zone: !ruby/object:ActiveSupport::TimeZone
                    name: Etc/UTC
                  time: 2023-06-06 20:07:17.000000000 Z
                categories:
                timeline:
                template_type: report
                where_clause:
                db_options:
                generate_cols:
                generate_rows:
                col_formats:
                tz:
                time_profile_id:
                display_filter:
                col_options:
                rpt_options:
                miq_group_id:
                user_id:
                menu_name: Guest OS Information - any OS
                userid: ''
                group_description: ''
            MiqSchedule:
              name: chart_guest_os_information_any_os
              description: chart_guest_os_information_any_os
              sched_action:
                :method: generate_widget
              filter: !ruby/object:MiqExpression
                exp:
                  "=":
                    field: MiqWidget-id
                    value: 1
                context_type:
                col_details:
                ruby:
              resource_type: MiqWidget
              run_at:
                :interval:
                  :value: '1'
                  :unit: daily
                :tz: UTC
                :start_time: !ruby/object:ActiveSupport::TimeWithZone
                  utc: &1 2023-07-11 00:00:00.000000000 Z
                  zone: !ruby/object:ActiveSupport::TimeZone
                    name: Etc/UTC
                  time: *1
              enabled: true
              userid: system
              prod_default: system
              adhoc:
              file_depot_id:
              resource_id:
      YAML

      MiqWidget.import(fd, :save => true)

      expect(MiqWidget.count).to eq(1)

      widget = MiqWidget.first
      expect(widget).to have_attributes(
        :guid          => "7e1fc241-5219-4ee2-8a8f-c4c2fdd587de",
        :description   => "chart_guest_os_information_any_os",
        :title         => "Guest OS Information",
        :content_type  => "chart",
        :options       => {:timezone_matters => false},
        :visibility    => {:roles => ["_ALL_"]},
        :user_id       => nil,
        :resource_type => "MiqReport",
        :enabled       => true,
        :read_only     => true
      )

      schedule = widget.miq_schedule
      expect(schedule).to have_attributes(
        :name          => "chart_guest_os_information_any_os",
        :description   => "chart_guest_os_information_any_os",
        :sched_action  => {:method => "generate_widget"},
        :resource_type => "MiqWidget",
        :enabled       => true,
        :userid        => "system",
        :prod_default  => "system",
        :adhoc         => nil,
        :file_depot_id => nil,
        :resource_id   => nil
      )

      filter = schedule.filter
      expect(filter).to be_a(MiqExpression)
      expect(filter.exp).to eq({"=" => {"field" => "MiqWidget-id", "value" => widget.id}})

      run_at = schedule.run_at
      expect(run_at[:start_time]).to be_a(ActiveSupport::TimeWithZone)
      expect(run_at[:start_time]).to eq(Time.zone.parse('2023-07-11 00:00:00.000000000 Z'))
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
