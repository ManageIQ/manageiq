require "spec_helper"

describe WidgetImportService do
  let(:widget_import_service) { described_class.new(widget_import_validator) }
  let(:widget_import_validator) { instance_double("WidgetImportValidator") }

  before do
    MiqServer.stub(:my_server).and_return(active_record_instance_double("MiqServer", :zone_id => 1))
  end

  describe "#cancel_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 42) }
    let(:miq_queue) { active_record_instance_double("MiqQueue") }

    before do
      ImportFileUpload.stub(:find).with("42").and_return(import_file_upload)
      import_file_upload.stub(:destroy)

      MiqQueue.stub(:unqueue)
    end

    it "destroys the import file upload" do
      import_file_upload.should_receive(:destroy)
      widget_import_service.cancel_import("42")
    end

    it "destroys the queued deletion" do
      MiqQueue.should_receive(:unqueue).with(
        :class_name  => "ImportFileUpload",
        :instance_id => 42,
        :method_name => "destroy"
      )
      widget_import_service.cancel_import("42")
    end
  end

  describe "#import_widgets" do
    let(:miq_queue) { active_record_instance_double("MiqQueue") }
    let(:yaml_data) { "the yaml" }
    let(:import_file_upload) do
      active_record_instance_double("ImportFileUpload", :id => 42, :uploaded_content => yaml_data)
    end
    let(:widgets_to_import) { %w(potato not_potato) }

    let(:miq_report_contents) do
      [{
        "MiqReport" => {
          "menu_name" => "menu name",
          "title"     => "title",
          "db"        => "Vm",
          "rpt_group" => "Custom",
          "rpt_type"  => "Custom"
        }
      }]
    end

    let(:miq_schedule_contents) do
      {
        "name"        => "schedule name",
        "description" => "new schedule description",
        "towhat"      => "MiqWidget",
        "run_at"      => {
          :start_time => Time.now,
          :tz         => "UTC",
          :interval   => {
            :unit  => "daily",
            :value => "6"
          }
        }
      }
    end

    let(:widgets) do
      [{
        "MiqWidget" => {
          "description"      => "Test",
          "MiqReportContent" => miq_report_contents,
          "MiqSchedule"      => miq_schedule_contents,
          "resource_id"      => "123",
          "title"            => "not_potato"
        }
      }, {
        "MiqWidget" => {
          "description" => "Test2",
          "title"       => "potato"
        }
      }]
    end

    before do
      import_file_upload.stub(:destroy)
      MiqQueue.stub(:unqueue)
    end

    shared_examples_for "WidgetImportService#import_widgets that destroys temporary data" do
      it "destroys the import file upload" do
        import_file_upload.should_receive(:destroy)
        widget_import_service.import_widgets(import_file_upload, widgets_to_import)
      end

      it "unqueues the miq_queue item" do
        MiqQueue.should_receive(:unqueue).with(
          :class_name  => "ImportFileUpload",
          :instance_id => 42,
          :method_name => "destroy"
        )
        widget_import_service.import_widgets(import_file_upload, widgets_to_import)
      end
    end

    shared_examples_for "WidgetImportService#import_widgets with a non existing widget" do
      it "builds a new widget" do
        widget_import_service.import_widgets(import_file_upload, widgets_to_import)
        MiqWidget.first.should_not be_nil
      end
    end

    context "when the YAML loaded is widgets" do
      context "when the list of widgets to import from the yaml includes an existing widget" do
        before do
          MiqWidget.create!(:description => "Test2", :title => "potato", :content_type => "report")
          YAML.stub(:load).with(yaml_data) do
            YAML.unstub(:load)
            widgets
          end
        end

        it_behaves_like "WidgetImportService#import_widgets that destroys temporary data"

        it "overwrites the existing widget" do
          widget_import_service.import_widgets(import_file_upload, widgets_to_import)
          expect(MiqWidget.where(:description => "Test2").first.title).to eq("potato")
        end
      end

      context "when the list of widgets to import from the yaml do not include an existing widget" do
        context "when the report is an RssFeed" do
          let(:miq_report_contents) do
            [{
              "RssFeed" => {
                "name"  => "name",
                "title" => "new title"
              }
            }]
          end

          context "when the RssFeed already exists" do
            before do
              RssFeed.create!(:name => "name", :title => "old title")
              YAML.stub(:load).with(yaml_data) do
                YAML.unstub(:load)
                widgets
              end
            end

            it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

            it "does not update the rss feed" do
              widget_import_service.import_widgets(import_file_upload, widgets_to_import)
              expect(RssFeed.first.title).to eq("old title")
            end
          end

          context "when the RssFeed does not already exist" do
            before do
              YAML.stub(:load).with(yaml_data) do
                YAML.unstub(:load)
                widgets
              end
            end

            it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

            it "builds a new RssFeed" do
              widget_import_service.import_widgets(import_file_upload, widgets_to_import)
              expect(RssFeed.first.title).to eq("new title")
            end
          end
        end

        context "when the report with the same name already exists" do
          before do
            MiqReport.create!(
              :db        => "Vm",
              :name      => "menu name",
              :rpt_group => "Custom",
              :rpt_type  => "Custom",
              :title     => "original report title"
            )
            YAML.stub(:load).with(yaml_data) do
              YAML.unstub(:load)
              widgets
            end
          end

          it_behaves_like "WidgetImportService#import_widgets that destroys temporary data"
          it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

          it "uses the existing report" do
            widget_import_service.import_widgets(import_file_upload, widgets_to_import)
            widget = MiqWidget.first
            expect(widget.resource).to eq(MiqReport.first)
            expect(MiqReport.first.title).to eq("original report title")
          end
        end

        context "when the report does not exist" do
          before do
            YAML.stub(:load).with(yaml_data) do
              YAML.unstub(:load)
              widgets
            end
          end

          it_behaves_like "WidgetImportService#import_widgets that destroys temporary data"
          it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

          it "builds a report associated to the widget" do
            widget_import_service.import_widgets(import_file_upload, widgets_to_import)
            widget = MiqWidget.first
            expect(widget.resource).to eq(MiqReport.first)
          end
        end

        context "when the schedule does not exist" do
          before do
            YAML.stub(:load).with(yaml_data) do
              YAML.unstub(:load)
              widgets
            end
          end

          it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

          it "builds a new miq schedule associated to the widget" do
            widget_import_service.import_widgets(import_file_upload, widgets_to_import)
            widget = MiqWidget.first
            expect(widget.miq_schedule.description).to eq("new schedule description")
          end
        end

        context "when the schedule does exist" do
          before do
            MiqSchedule.create!(
              :name        => "schedule name",
              :description => "old schedule description",
              :towhat      => "MiqWidget",
              :run_at      => {
                :start_time => Time.now,
                :tz         => "UTC",
                :interval   => {:unit => "daily", :value => "6"}
              }
            )

            YAML.stub(:load).with(yaml_data) do
              YAML.unstub(:load)
              widgets
            end
          end

          it_behaves_like "WidgetImportService#import_widgets with a non existing widget"

          it "uses the existing schedule" do
            widget_import_service.import_widgets(import_file_upload, widgets_to_import)
            widget = MiqWidget.first
            expect(widget.miq_schedule.description).to eq("old schedule description")
          end
        end
      end

      context "when the list of widgets is nil" do
        let(:widgets_to_import) { nil }

        it_behaves_like "WidgetImportService#import_widgets that destroys temporary data"

        it "does not error" do
          expect { widget_import_service.import_widgets(import_file_upload, widgets_to_import) }.to_not raise_error
        end
      end
    end

    context "when the loaded yaml does not return widgets" do
      before do
        YAML.stub(:load).with(yaml_data).and_return([{"MiqWidget" => {"not a" => "widget"}}])
      end

      it "raises a ParsedNonWidgetYamlError" do
        expect { widget_import_service.import_widgets(import_file_upload, widgets_to_import) }.to raise_error(
          WidgetImportService::ParsedNonWidgetYamlError
        )
      end
    end
  end

  describe "#store_for_import" do
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload", :id => 42).as_null_object }

    before do
      ImportFileUpload.stub(:create).and_return(import_file_upload)
      import_file_upload.stub(:store_binary_data_as_yml)
      MiqQueue.stub(:put)
    end

    context "when the imported file does not raise any errors while determining validity" do
      before do
        widget_import_validator.stub(:determine_validity).with(import_file_upload).and_return(nil)
      end

      it "stores the data" do
        import_file_upload.should_receive(:store_binary_data_as_yml).with("the data", "Widget import")
        widget_import_service.store_for_import("the data")
      end

      it "returns the imported file upload" do
        expect(widget_import_service.store_for_import("the data")).to eq(import_file_upload)
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          MiqQueue.should_receive(:put).with(
            :class_name  => "ImportFileUpload",
            :instance_id => 42,
            :deliver_on  => 1.day.from_now,
            :method_name => "destroy"
          )

          widget_import_service.store_for_import("the data")
        end
      end
    end

    context "when the imported file raises an error while determining validity" do
      before do
        error_to_be_raised = WidgetImportValidator::NonYamlError.new("Test message")
        widget_import_validator.stub(:determine_validity).with(import_file_upload).and_raise(error_to_be_raised)
      end

      it "reraises with the original error" do
        expect {
          widget_import_service.store_for_import("the data")
        }.to raise_error(WidgetImportValidator::NonYamlError, "Test message")
      end

      it "queues a deletion" do
        Timecop.freeze(2014, 3, 5) do
          MiqQueue.should_receive(:put).with(
            :class_name  => "ImportFileUpload",
            :instance_id => 42,
            :deliver_on  => 1.day.from_now,
            :method_name => "destroy"
          )

          begin
            widget_import_service.store_for_import("the data")
          rescue WidgetImportValidator::NonYamlError
            nil
          end
        end
      end
    end
  end
end
