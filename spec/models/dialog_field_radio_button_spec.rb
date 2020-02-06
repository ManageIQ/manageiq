RSpec.describe DialogFieldRadioButton do
  let(:dialog_field_radio_button) do
    DialogFieldRadioButton.new(
      :dialog          => dialog,
      :resource_action => resource_action
    )
  end

  let(:dialog) { Dialog.new }
  let(:resource_action) { ResourceAction.new }

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

  describe "#refresh_json_value" do
    before do
      dialog_field_radio_button.dynamic = true
      dialog_field_radio_button.default_value = "123"
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate)
        .and_return(refreshed_values_from_automate)
    end

    context "when the checked value is in the list of refreshed values" do
      let(:refreshed_values_from_automate) { [%w(123 123), %w(456 456)] }

      it "returns the list of refreshed values and checked value as a hash" do
        expect(dialog_field_radio_button.refresh_json_value("123")).to eq(
          :refreshed_values => refreshed_values_from_automate,
          :checked_value    => "123",
          :read_only        => false,
          :visible          => true
        )
      end
    end

    context "when the checked value is not in the list of refreshed values" do
      let(:refreshed_values_from_automate) { [%w(123 123)] }

      it "returns the list of refreshed values and no checked (default) value as a hash" do
        expect(dialog_field_radio_button.refresh_json_value("321")).to eq(
          :refreshed_values => refreshed_values_from_automate,
          :checked_value    => nil,
          :read_only        => false,
          :visible          => true
        )
      end
    end
  end
end
