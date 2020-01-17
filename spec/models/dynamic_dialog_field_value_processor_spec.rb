RSpec.describe DynamicDialogFieldValueProcessor do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:dynamic_dialog_field_value_processor) { described_class.new }

  describe "#values_from_automate" do
    let(:dialog) do
      double(
        "Dialog",
        :automate_values_hash => "automate_values_hash",
        :target_resource      => "target_resource"
      )
    end

    let(:dialog_field) do
      double(
        "DialogFieldRadioButton",
        :initial_values      => "initial_values",
        :script_error_values => "script error values"
      )
    end
    let(:resource_action) { double("ResourceAction") }

    before do
      allow(dialog_field).to receive(:dialog).and_return(dialog)
      allow(dialog_field).to receive(:resource_action).and_return(resource_action)
    end

    context "when there is no error delivering to automate from dialog field" do
      let(:workspace) { double("MiqAeEngine::MiqAeWorkspaceRuntime") }
      let(:workspace_attributes) do
        double(
          :attributes => {
            "sort_by"       => "none",
            "sort_order"    => "descending",
            "data_type"     => "datatype",
            "default_value" => "default",
            "required"      => true,
            "values"        => "workspace values"
          }
        )
      end

      before do
        User.current_user = user
        allow(resource_action).to receive(:deliver_to_automate_from_dialog_field).with(
          {:dialog => "automate_values_hash"},
          "target_resource",
          user
        ).and_return(workspace)
        allow(workspace).to receive(:root).and_return(workspace_attributes)
        allow(dialog_field).to receive(:normalize_automate_values).with(workspace_attributes.attributes).and_return(
          "normalized values"
        )
      end

      it "returns the normalized values" do
        expect(dynamic_dialog_field_value_processor.values_from_automate(dialog_field)).to eq("normalized values")
      end
    end

    context "when there is an error delivering to automate from dialog field" do
      before do
        allow(resource_action).to receive(:deliver_to_automate_from_dialog_field).and_raise("O noes")
      end

      it "returns the dialog field's script error values" do
        expect(dynamic_dialog_field_value_processor.values_from_automate(dialog_field)).to eq("script error values")
      end
    end
  end
end
