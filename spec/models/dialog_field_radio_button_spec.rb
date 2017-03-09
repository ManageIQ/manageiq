describe DialogFieldRadioButton do
  let(:dialog_field_radio_button) do
    DialogFieldRadioButton.new(
      :dialog          => dialog,
      :resource_action => resource_action
    )
  end

  let(:dialog) { Dialog.new }
  let(:resource_action) { ResourceAction.new }

  describe "#initialize_with_values" do
    context "when show refresh button is true" do
      before do
        dialog_field_radio_button.show_refresh_button = true
      end

      context "when load values on init is true" do
        before do
          dialog_field_radio_button.load_values_on_init = true
        end

        context "when the dialog field is dynamic" do
          let(:processed_values) { [["processor", 123], ["test", 456]] }

          before do
            dialog_field_radio_button.dynamic = true
            dialog_field_radio_button.default_value = "test"
            allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate)
              .with(dialog_field_radio_button).and_return(processed_values)

            dialog_field_radio_button.initialize_with_values("lolvalues" => 321)
          end

          it "gets values from automate" do
            expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq(processed_values)
          end

          it "sets value from default value attribute" do
            expect(dialog_field_radio_button.instance_variable_get(:@value)).to eq("test")
          end
        end

        context "when the dialog field is not dynamic" do
          before do
            dialog_field_radio_button.dynamic = false
            dialog_field_radio_button.values = [["testing", 123]]
            dialog_field_radio_button.initialize_with_values("lolvalues" => 321)
          end

          it "sets raw values from values attribute" do
            expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq(
              [["testing", 123]]
            )
          end
        end
      end

      context "when load values on init is false" do
        before do
          dialog_field_radio_button.load_values_on_init = false
          dialog_field_radio_button.initialize_with_values("lolvalues" => 321)
        end

        it "sets raw_values to initial values" do
          expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq([[nil, "<None>"]])
        end
      end
    end

    context "when show refresh button is false" do
      before do
        dialog_field_radio_button.show_refresh_button = false
      end

      context "when the dialog field is dynamic" do
        before do
          dialog_field_radio_button.dynamic = true
          allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate)
            .with(dialog_field_radio_button).and_return(
              [["processor", 123]]
            )

          dialog_field_radio_button.initialize_with_values("lolvalues" => 321)
        end

        it "gets values from automate" do
          expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq([["processor", 123]])
        end
      end

      context "when the dialog field is not dynamic" do
        before do
          dialog_field_radio_button.dynamic = false
          dialog_field_radio_button.values = [["testing", 123]]
          dialog_field_radio_button.initialize_with_values("lolvalues" => 321)
        end

        it "gets values from values attribute" do
          expect(dialog_field_radio_button.instance_variable_get(:@raw_values)).to eq(
            [["testing", 123]]
          )
        end
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
