require "spec_helper"

describe ImportFileUpload do
  let(:import_file_upload) { described_class.new }

  describe "#policy_import_data" do
    let(:policy_array) { "policy array" }

    before do
      import_file_upload.create_binary_blob(:binary => "---\n- :file: contents\n")
      MiqPolicy.stub(:import_from_array).with([{:file => "contents"}], :preview => true).and_return(policy_array)
    end

    it "returns the imported policy array" do
      import_file_upload.policy_import_data.should == "policy array"
    end
  end

  describe "#service_dialog_json" do
    before do
      import_file_upload.create_binary_blob(:binary => "---\n- label: Dialog2\n- label: dialog\n  not_label: test\n")
      Dialog.stub(:exists?).with(:label => "dialog").and_return(exists?)
      Dialog.stub(:exists?).with(:label => "Dialog2").and_return(exists?)
    end

    context "when a given dialog exists" do
      let(:exists?) { true }

      it "returns json with a checkmark status icon" do
        expected_json = [{
            :id          => 0,
            :name        => "dialog",
            :status_icon => "checkmark",
            :status      => "This object already exists in the database with the same name"
          }, {
            :id          => 1,
            :name        => "Dialog2",
            :status_icon => "checkmark",
            :status      => "This object already exists in the database with the same name"
        }].to_json

        import_file_upload.service_dialog_json.should == expected_json
      end
    end

    context "when a given dialog does not exist" do
      let(:exists?) { false }

      it "returns json with an equal-green status icon" do
        expected_json = [{
            :id          => 0,
            :name        => "dialog",
            :status_icon => "equal-green",
            :status      => "New object"
          }, {
            :id          => 1,
            :name        => "Dialog2",
            :status_icon => "equal-green",
            :status      => "New object"
        }].to_json

        import_file_upload.service_dialog_json.should == expected_json
      end
    end
  end

  describe "#widget_json" do
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
      MiqWidget.stub(:exists?).with(:title => "widget").and_return(exists?)
      MiqWidget.stub(:exists?).with(:title => "Widget1").and_return(exists?)
    end

    context "when a given widget exists" do
      let(:exists?) { true }

      it "returns json with a checkmark status icon" do
        expected_json = [{
          :id          => 0,
          :name        => "widget",
          :status_icon => "checkmark",
          :status      => "This object already exists in the database with the same name"
        }, {
          :id          => 1,
          :name        => "Widget1",
          :status_icon => "checkmark",
          :status      => "This object already exists in the database with the same name"
        }].to_json

        expect(import_file_upload.widget_json).to eq(expected_json)
      end
    end

    context "when a given widget does not exist" do
      let(:exists?) { false }

      it "returns json with an equal-green status icon" do
        expected_json = [{
          :id          => 0,
          :name        => "widget",
          :status_icon => "equal-green",
          :status      => "New object"
        }, {
          :id          => 1,
          :name        => "Widget1",
          :status_icon => "equal-green",
          :status      => "New object"
        }].to_json

        expect(import_file_upload.widget_json).to eq(expected_json)
      end
    end
  end

  describe "#store_policy_import_data" do
    before do
      import_file_upload.store_policy_import_data("123")
    end

    it "stores the binary blob binary data" do
      import_file_upload.binary_blob.binary.should == "123"
    end

    it "stores the binary blob name" do
      import_file_upload.binary_blob.name.should == "Policy import"
    end

    it "stores the binary blob data type" do
      import_file_upload.binary_blob.data_type.should == "yml"
    end
  end

  describe "#store_service_dialog_import_data" do
    before do
      import_file_upload.store_service_dialog_import_data("123")
    end

    it "stores the binary blob binary data" do
      import_file_upload.binary_blob.binary.should == "123"
    end

    it "stores the binary blob name" do
      import_file_upload.binary_blob.name.should == "Service Dialog import"
    end

    it "stores the binary blob data type" do
      import_file_upload.binary_blob.data_type.should == "yml"
    end
  end

  describe "#store_widget_import_data" do
    before do
      import_file_upload.store_widget_import_data("123")
    end

    it "stores the binary blob binary data" do
      expect(import_file_upload.binary_blob.binary).to eq("123")
    end

    it "stores the binary blob name" do
      expect(import_file_upload.binary_blob.name).to eq("Widget import")
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
      import_file_upload.uploaded_content.should == "binary data"
    end
  end

  describe "#uploaded_yaml_content" do
    before do
      import_file_upload.create_binary_blob(:binary => "---\n- :file: contents\n")
    end

    it "returns the binary_blob data parsed as yaml" do
      import_file_upload.uploaded_yaml_content.should == [{:file => "contents"}]
    end
  end
end
