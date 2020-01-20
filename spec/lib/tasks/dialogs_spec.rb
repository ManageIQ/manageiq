require "rake"

RSpec.describe "dialogs" do
  let(:task_path) { "lib/tasks/dialogs" }

  describe "import", :type => :rake_task do
    let(:dialog_import_helper) { double("TaskHelpers::DialogImportHelper") }

    before do
      allow(TaskHelpers::DialogImportHelper).to receive(:new).and_return(dialog_import_helper)
    end

    it "depends on the environment" do
      expect(Rake::Task["dialogs:import"].prerequisites).to include("environment")
    end

    it "delegates to a dialog import helper" do
      expect(dialog_import_helper).to receive(:import).with("filename")
      Rake::Task["dialogs:import"].invoke("filename")
    end
  end

  describe "export", :type => :rake_task do
    let(:dialog_exporter) { double("TaskHelpers::DialogExporter") }

    before do
      allow(TaskHelpers::DialogExporter).to receive(:new).and_return(dialog_exporter)
    end

    it "depends on the environment" do
      expect(Rake::Task["dialogs:export"].prerequisites).to include("environment")
    end

    context "with a given filename" do
      it "delegates to a dialog exporter with the given filename" do
        expect(dialog_exporter).to receive(:export).with("filename")
        Rake::Task["dialogs:export"].invoke("filename")
      end
    end

    context "without a given filename" do
      it "delegates to a dialog exporter with a default filename and timestamp" do
        Timecop.freeze(2013, 1, 1) do
          expect(dialog_exporter).to receive(:export).with("dialog_export_20130101_000000.yml")
          Rake::Task["dialogs:export"].invoke
        end
      end
    end
  end
end
