require "spec_helper"

describe TaskHelpers::DialogExporter do
  let(:dialog_yaml_serializer) { instance_double("DialogYamlSerializer") }

  let(:dialog_exporter) { described_class.new(dialog_yaml_serializer) }

  describe "#export" do
    let(:file) { double }
    let(:filename) { "filename" }

    before do
      File.stub(:write)
      dialog_yaml_serializer.stub(:serialize).and_return("dialog_yaml")
      Dialog.stub(:all).and_return(["all the dialogs"])
    end

    it "exports the dialog yaml to the filename" do
      dialog_yaml_serializer.should_receive(:serialize).with(["all the dialogs"])
      dialog_exporter.export(filename)
    end

    it "writes the serialized yaml to the file" do
      File.should_receive(:write).with(filename, "dialog_yaml")
      dialog_exporter.export(filename)
    end
  end
end
