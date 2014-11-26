require "spec_helper"
require "debugger"

describe DialogFieldRadioButton do
  let(:dialog_field_radio_button) do
    DialogFieldRadioButton.new(
      :dialog          => dialog,
      :resource_action => resource_action
    )
  end

  let(:dialog) { Dialog.new }
  let(:resource_action) { ResourceAction.new }

  describe "#refresh_button_pressed" do
    let(:dialog_values) { {:dialog => "automate_values_hash"} }
    let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspaceRuntime") }
    let(:workspace_attributes) do
      double(:attributes => {
        "sort_by"       => "none",
        "sort_order"    => "descending",
        "data_type"     => "datatype",
        "default_value" => "default",
        "values"        => workspace_attribute_values
      })
    end

    before do
      dialog.stub(:automate_values_hash).and_return("automate_values_hash")
      dialog.stub(:target_resource).and_return("target_resource")

      resource_action.stub(:deliver_to_automate_from_dialog_field).with(dialog_values, "target_resource").and_return(workspace)

      workspace.stub(:root).and_return(workspace_attributes)
    end

    shared_examples_for "DialogFieldRadioButton#refresh_button_pressed" do
      it "sets the sort by" do
        dialog_field_radio_button.refresh_button_pressed
        expect(dialog_field_radio_button.sort_by).to eq(:none)
      end

      it "sets the sort order" do
        dialog_field_radio_button.refresh_button_pressed
        expect(dialog_field_radio_button.sort_order).to eq(:descending)
      end

      it "sets the data type" do
        dialog_field_radio_button.refresh_button_pressed
        expect(dialog_field_radio_button.data_type).to eq("datatype")
      end

      it "sets the default value" do
        dialog_field_radio_button.refresh_button_pressed
        expect(dialog_field_radio_button.default_value).to eq("default")
      end
    end

    context "when the workspace attribute values exist" do
      let(:workspace_attribute_values) { [["123", "456"]] }

      it_behaves_like "DialogFieldRadioButton#refresh_button_pressed"

      it "returns the dialog values" do
        expect(dialog_field_radio_button.refresh_button_pressed).to eq([["123", "456"]])
      end
    end

    context "when the workspace attributes values do not exist" do
      let(:workspace_attribute_values) { nil }

      it_behaves_like "DialogFieldRadioButton#refresh_button_pressed"

      it "returns the initial values" do
        expect(dialog_field_radio_button.refresh_button_pressed).to eq([["", "<None>"]])
      end
    end
  end

  describe "#initialize_with_values" do
    context "when show refresh button is true" do
      before do
        dialog_field_radio_button.show_refresh_button = true
      end

      context "when load values on init is true" do
        before do
          dialog_field_radio_button.load_values_on_init = true
          dialog_field_radio_button.initialize_with_values("lolvalues")
        end

        it "gets values from automate" do
          # Since we are testing the values from automate piece in the above #refresh_button pressed, I think it is
          # ok to let this one fail through and expect the rescued values

          expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq([[nil, "<Script error>"]])
        end
      end

      context "when load values on init is false" do
        before do
          dialog_field_radio_button.load_values_on_init = false
          dialog_field_radio_button.initialize_with_values("lolvalues")
        end

        it "sets raw_values to initial values" do
          expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq([["", "<None>"]])
        end
      end
    end

    context "when show refresh button is false" do
      before do
        dialog_field_radio_button.show_refresh_button = false
        dialog_field_radio_button.initialize_with_values("lolvalues")
      end


      it "gets values from automate" do
        expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq([[nil, "<Script error>"]])
      end
    end
  end

  describe "#show_refresh_button?" do
    context "when show refresh button is true" do
      before do
        dialog_field_radio_button.show_refresh_button = true
      end

      it "returns true" do
        expect(dialog_field_radio_button.show_refresh_button?).to be(true)
      end
    end

    context "when show refresh button is false" do
      before do
        dialog_field_radio_button.show_refresh_button = false
      end

      it "returns false" do
        expect(dialog_field_radio_button.show_refresh_button?).to be(false)
      end
    end

    context "when show refresh button is nil" do
      before do
        dialog_field_radio_button.show_refresh_button = nil
      end

      it "returns false" do
        expect(dialog_field_radio_button.show_refresh_button?).to be(false)
      end
    end
  end
end
