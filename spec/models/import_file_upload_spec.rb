RSpec.describe ImportFileUpload do
  let(:import_file_upload) { described_class.create }

  describe "#policy_import_data" do
    let(:policy_array) { "policy array" }

    before do
      import_file_upload.create_binary_blob(:binary => "---\n- :file: contents\n")
      allow(MiqPolicy).to receive(:import_from_array).with([{:file => "contents"}], :preview => true).and_return(policy_array)
    end

    it "returns the imported policy array" do
      expect(import_file_upload.policy_import_data).to eq("policy array")
    end
  end

  describe "#service_dialog_list" do
    before do
      import_file_upload.create_binary_blob(:binary => "---\n- label: Dialog2\n- label: dialog\n  not_label: test\n")
      allow(Dialog).to receive(:exists?).with(:label => "dialog").and_return(exists?)
      allow(Dialog).to receive(:exists?).with(:label => "Dialog2").and_return(exists?)
    end

    context "when a given dialog exists" do
      let(:exists?) { true }

      it "returns json with a checkmark status icon" do
        expected_list = [{
          :id     => 0,
          :name   => "dialog",
          :exists => true
        }, {
          :id     => 1,
          :name   => "Dialog2",
          :exists => true
        }]

        expect(import_file_upload.service_dialog_list).to eq(expected_list)
      end
    end

    context "when a given dialog does not exist" do
      let(:exists?) { false }

      it "returns json with an equal-green status icon" do
        expected_list = [{
          :id     => 0,
          :name   => "dialog",
          :exists => false
        }, {
          :id     => 1,
          :name   => "Dialog2",
          :exists => false
        }]

        expect(import_file_upload.service_dialog_list).to eq(expected_list)
      end
    end
  end

  describe "#widget_list" do
    before do
      import_file_upload.create_binary_blob(
        :binary => <<-BINARY
---
- MiqWidget:
    title: Widget1
- MiqWidget:
    title: widget
    not_name: test
        BINARY
      )
      allow(MiqWidget).to receive(:exists?).with(:title => "widget").and_return(exists?)
      allow(MiqWidget).to receive(:exists?).with(:title => "Widget1").and_return(exists?)
    end

    context "when a given widget exists" do
      let(:exists?) { true }

      it "returns json with a checkmark status icon" do
        expected_list = [{
          :id     => 0,
          :name   => "widget",
          :exists => true
        }, {
          :id     => 1,
          :name   => "Widget1",
          :exists => true
        }]

        expect(import_file_upload.widget_list).to eq(expected_list)
      end
    end

    context "when a given widget does not exist" do
      let(:exists?) { false }

      it "returns json with an equal-green status icon" do
        expected_list = [{
          :id     => 0,
          :name   => "widget",
          :exists => false
        }, {
          :id     => 1,
          :name   => "Widget1",
          :exists => false
        }]

        expect(import_file_upload.widget_list).to eq(expected_list)
      end
    end
  end

  describe "#store_binary_data_as_yml" do
    before do
      import_file_upload.store_binary_data_as_yml("123", "the name")
    end

    it "stores the binary blob binary data" do
      expect(import_file_upload.binary_blob.binary).to eq("123")
    end

    it "stores the binary blob name" do
      expect(import_file_upload.binary_blob.name).to eq("the name")
    end

    it "stores the binary blob data type" do
      expect(import_file_upload.binary_blob.data_type).to eq("yml")
    end
  end

  describe "#uploaded_content" do
    before do
      import_file_upload.create_binary_blob(:binary => "binary data")
    end

    it "returns the binary_blob binary data" do
      expect(import_file_upload.uploaded_content).to eq("binary data")
    end
  end

  describe "#uploaded_yaml_content" do
    before do
      import_file_upload.create_binary_blob(:binary => "---\n- :file: contents\n")
    end

    it "returns the binary_blob data parsed as yaml" do
      expect(import_file_upload.uploaded_yaml_content).to eq([{:file => "contents"}])
    end
  end
end
