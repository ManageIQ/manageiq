require "spec_helper"
require "rake"

describe "dialogs" do
  let(:task_path) { "lib/tasks/dialogs" }

  describe "import", :type => :rake_task do
    let(:dialog_import_helper) { instance_double("TaskHelpers::DialogImportHelper") }

    before do
      TaskHelpers::DialogImportHelper.stub(:new).and_return(dialog_import_helper)
    end

    it "depends on the environment" do
      Rake::Task["dialogs:import"].prerequisites.should include("environment")
    end

    it "delegates to a dialog import helper" do
      dialog_import_helper.should_receive(:import).with("filename")
      Rake::Task["dialogs:import"].invoke("filename")
    end
  end

  describe "export", :type => :rake_task do
    let(:dialog_exporter) { instance_double("TaskHelpers::DialogExporter") }

    before do
      TaskHelpers::DialogExporter.stub(:new).and_return(dialog_exporter)
    end

    it "depends on the environment" do
      Rake::Task["dialogs:export"].prerequisites.should include("environment")
    end

    context "with a given filename" do
      it "delegates to a dialog exporter with the given filename" do
        dialog_exporter.should_receive(:export).with("filename")
        Rake::Task["dialogs:export"].invoke("filename")
      end
    end

    context "without a given filename" do
      it "delegates to a dialog exporter with a default filename and timestamp" do
        Timecop.freeze(2013, 1, 1) do
          dialog_exporter.should_receive(:export).with("dialog_export_20130101_000000.yml")
          Rake::Task["dialogs:export"].invoke
        end
      end
    end
  end
end
