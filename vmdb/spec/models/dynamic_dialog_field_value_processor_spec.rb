require "spec_helper"

describe DynamicDialogFieldValueProcessor do
  let(:dynamic_dialog_field_value_processor) { described_class.new }

  describe "#values_from_automate" do
    shared_examples_for "DynamicDialogFieldValueProcessor#values_from_automate processing workspace values" do
      it "sets the sort_by" do
        dialog_field.should_receive(:sort_by=).with("none")
        dynamic_dialog_field_value_processor.values_from_automate(dialog_field)
      end

      it "sets the sort_order" do
        dialog_field.should_receive(:sort_order=).with("descending")
        dynamic_dialog_field_value_processor.values_from_automate(dialog_field)
      end

      it "sets the data_type" do
        dialog_field.should_receive(:data_type=).with("datatype")
        dynamic_dialog_field_value_processor.values_from_automate(dialog_field)
      end

      it "sets the default_value" do
        dialog_field.should_receive(:default_value=).with("default")
        dynamic_dialog_field_value_processor.values_from_automate(dialog_field)
      end

      it "sets the required" do
        dialog_field.should_receive(:required=).with(true)
        dynamic_dialog_field_value_processor.values_from_automate(dialog_field)
      end
    end

    let(:dialog) do
      active_record_instance_double(
        "Dialog",
        :automate_values_hash => "automate_values_hash",
        :target_resource      => "target_resource"
      )
    end

    let(:dialog_field) { active_record_instance_double("DialogFieldRadioButton", :initial_values => "initial_values") }
    let(:resource_action) { active_record_instance_double("ResourceAction") }

    before do
      dialog_field.stub(:dialog).and_return(dialog)
      dialog_field.stub(:resource_action).and_return(resource_action)
    end

    context "when there is no error delivering to automate from dialog field" do
      let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspaceRuntime") }
      let(:workspace_attributes) do
        double(
          :attributes => {
            "sort_by"       => "none",
            "sort_order"    => "descending",
            "data_type"     => "datatype",
            "default_value" => "default",
            "required"      => true,
            "values"        => workspace_attribute_values
          }
        )
      end

      before do
        resource_action.stub(:deliver_to_automate_from_dialog_field).with(
          {:dialog => "automate_values_hash"},
          "target_resource"
        ).and_return(workspace)
        workspace.stub(:root).and_return(workspace_attributes)
        dialog_field.stub(:sort_by=)
        dialog_field.stub(:sort_order=)
        dialog_field.stub(:data_type=)
        dialog_field.stub(:default_value=)
        dialog_field.stub(:required=)
      end

      context "when the workspace attributes have values" do
        let(:workspace_attribute_values) { [[123, "456"]] }

        it_behaves_like "DynamicDialogFieldValueProcessor#values_from_automate processing workspace values"

        it "returns the given values" do
          expect(dynamic_dialog_field_value_processor.values_from_automate(dialog_field)).to eq([[123, "456"]])
        end
      end

      context "when the workspace attributes do not have values" do
        let(:workspace_attribute_values) { nil }

        it_behaves_like "DynamicDialogFieldValueProcessor#values_from_automate processing workspace values"

        it "returns the initial values" do
          expect(dynamic_dialog_field_value_processor.values_from_automate(dialog_field)).to eq("initial_values")
        end
      end
    end

    context "when there is an error delivering to automate from dialog field" do
      before do
        resource_action.stub(:deliver_to_automate_from_dialog_field).and_raise("O noes")
      end

      it "returns a script error" do
        expect(dynamic_dialog_field_value_processor.values_from_automate(dialog_field)).to eq([[nil, "<Script error>"]])
      end
    end
  end
end
