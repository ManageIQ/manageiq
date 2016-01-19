describe TaskHelpers::DialogImportHelper do
  let(:dialog_import_service) { double("DialogImportService") }
  let(:dialog_import_helper) { described_class.new(dialog_import_service) }

  describe "#import" do
    let(:filename) { "filename" }

    before do
      allow($log).to receive(:info)
      allow(Kernel).to receive(:puts)
    end

    it "logs a message for yielded results" do
      allow(dialog_import_service).to receive(:import_from_file).with(filename).and_yield("label" => "label")
      expect($log).to receive(:info).with("Skipping importing of dialog with label label as it already exists")
      dialog_import_helper.import(filename)
    end

    it "delegates to the dialog_import_service" do
      expect(dialog_import_service).to receive(:import_from_file).with(filename).and_yield("label" => "label")
      dialog_import_helper.import(filename)
    end
  end
end
