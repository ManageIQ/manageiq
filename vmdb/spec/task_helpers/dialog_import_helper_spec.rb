require "spec_helper"

describe TaskHelpers::DialogImportHelper do
  let(:dialog_import_service) { instance_double("DialogImportService") }
  let(:dialog_import_helper) { described_class.new(dialog_import_service) }

  describe "#import" do
    let(:filename) { "filename" }

    before do
      $log.stub(:info)
      Kernel.stub(:puts)
    end

    it "logs a message for yielded results" do
      dialog_import_service.stub(:import_from_file).with(filename).and_yield("label" => "label")
      $log.should_receive(:info).with("Skipping importing of dialog with label label as it already exists")
      dialog_import_helper.import(filename)
    end

    it "delegates to the dialog_import_service" do
      dialog_import_service.should_receive(:import_from_file).with(filename).and_yield("label" => "label")
      dialog_import_helper.import(filename)
    end
  end
end
