RSpec.describe DialogField do
  context "legacy tests" do

    let(:df) { FactoryBot.create(:dialog_field) }
    it "sets default value for required attribute" do
      expect(df.required).to eq(false)
      expect(df.visible).to eq(true)
    end

    it "fields named 'action' or 'controller' are invalid" do
      action_field = FactoryBot.build(:dialog_field, :name => 'action')
      expect(action_field).not_to be_valid
      controller_field = FactoryBot.build(:dialog_field, :name => 'controller')
      expect(controller_field).not_to be_valid
      foo_field = FactoryBot.build(:dialog_field, :name => 'foo')
      expect(foo_field).to be_valid
    end

    it "supports more than 255 characters within default_value" do
      str = "0" * 10000
      df.default_value = str
      expect { df.save }.to_not raise_error
      df.reload
      expect(df.default_value).to eq(str)
    end

    describe "#validate" do
      let(:visible_dialog_field) do
        described_class.new(:label    => 'dialog_field',
                            :name     => 'dialog_field',
                            :required => required,
                            :value    => value,
                            :visible  => true)
      end
      let(:invisible_dialog_field) do
        described_class.new(:label    => 'dialog_field',
                            :name     => 'dialog_field',
                            :required => required,
                            :value    => value,
                            :visible  => false)
      end

      let(:dialog_tab)   { double('DialogTab',   :label => 'tab') }
      let(:dialog_group) { double('DialogGroup', :label => 'group') }

      shared_examples_for "DialogField#validate that returns nil" do
        it "returns nil" do
          expect(invisible_dialog_field.validate_field_data(dialog_tab, dialog_group)).to be_nil
        end
      end

      context "when visible is true" do
        let(:visible) { true }
        context "when required is true" do
          let(:required) { true }
          context "with a blank value" do
            let(:value) { "" }
            it "returns error message" do
              expect(visible_dialog_field.validate_field_data(dialog_tab, dialog_group))
                .to eq("tab/group/dialog_field is required")
            end
          end
          context "with a non-blank value" do
            let(:value) { "test value" }
            it_behaves_like "DialogField#validate that returns nil"
          end
        end
        context "when required is false" do
          let(:required) { false }
          context "with a blank value" do
            let(:value) { "" }
            it_behaves_like "DialogField#validate that returns nil"
          end
          context "with a non-blank value" do
            let(:value) { "test value" }
            it_behaves_like "DialogField#validate that returns nil"
          end
        end
      end

      context "when visible is false" do
        let(:visible) { false }
        context "when required is false" do
          let(:required) { false }
          context "with a blank value" do
            let(:value) { "test value" }
            it_behaves_like "DialogField#validate that returns nil"
          end
          context "with a non-blank value" do
            let(:value) { "test value" }
            it_behaves_like "DialogField#validate that returns nil"
          end
        end
        context "when required is true" do
          let(:required) { true }
          context "with a blank value" do
            let(:value) { "" }
            it_behaves_like "DialogField#validate that returns nil"
          end
          context "with a non-blank value" do
            let(:value) { "test value" }
            it_behaves_like "DialogField#validate that returns nil"
          end
        end
      end
    end
  end

  describe "#initialize_value_context" do
    let(:field) { described_class.new(:dynamic => dynamic, :value => value) }
    let(:field_with_default) { described_class.new(:dynamic => dynamic, :value => value, :default_value => "drew_was_here") }

    context "when the field is dynamic" do
      let(:dynamic) { true }

      context "when the value is blank" do
        let(:value) { "" }
        let(:automate_value) { "some value from automate" }

        before do
          allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).and_return(automate_value)
        end

        it "sets the value to the automate value" do
          field.initialize_value_context
          expect(field.instance_variable_get(:@value)).to eq("some value from automate")
        end
      end

      context "when the value is not blank" do
        let(:value) { "not blank" }

        it "does not adjust the value" do
          field.initialize_value_context
          expect(field.instance_variable_get(:@value)).to eq("not blank")
        end
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }

      context "with a user-adjusted value" do
        let(:value) { "not dynamic" }

        it "does not adjust the value" do
          field.initialize_value_context
          expect(field.instance_variable_get(:@value)).to eq("not dynamic")
        end
      end

      context "without a user-adjusted value" do
        context "with a default value" do
          let(:value) { nil }

          it "does adjust the value" do
            field_with_default.initialize_value_context
            expect(field_with_default.instance_variable_get(:@value)).to eq("drew_was_here")
          end
        end
      end
    end
  end

  describe "#initialize_static_values" do
    let(:field) { described_class.new(:dynamic => dynamic, :value => value) }
    let(:field_with_default) { described_class.new(:dynamic => dynamic, :value => value, :default_value => "test") }

    context "when the field is dynamic" do
      let(:dynamic) { true }
      let(:value) { "value" }

      it "does not change the value" do
        field.initialize_static_values
        expect(field.instance_variable_get(:@value)).to eq("value")
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }

      context "with a user-adjusted value" do
        let(:value) { "not dynamic" }

        it "does not adjust the value" do
          field.initialize_static_values
          expect(field.instance_variable_get(:@value)).to eq("not dynamic")
        end
      end

      context "without a user-adjusted value" do
        context "with a default value" do
          let(:value) { nil }

          it "does adjust the value" do
            field_with_default.initialize_static_values
            expect(field_with_default.instance_variable_get(:@value)).to eq("test")
          end
        end
      end
    end
  end

  describe "#initialize_with_given_value" do
    let(:field) { described_class.new(:default_value => "not the given value") }

    it "uses the given value" do
      field.initialize_with_given_value("given_value")
      expect(field.default_value).to eq("given_value")
    end
  end

  describe "#automate_output_values" do
    let(:dialog_field) { described_class.new(:data_type => data_type, :value => "123") }

    context "when the data type is integer" do
      let(:data_type) { "integer" }

      it "returns the value as an integer" do
        expect(dialog_field.automate_output_value).to eq(123)
      end
    end

    context "when the data type is not an integer" do
      let(:data_type) { "potato" }

      it "returns the value" do
        expect(dialog_field.automate_output_value).to eq("123")
      end
    end
  end

  describe "#update_and_serialize_values" do
    let(:dialog_field) { described_class.new }

    before do
      allow(DialogFieldSerializer).to receive(:serialize).with(dialog_field)
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
        "automate values"
      )
    end

    it "triggers an automate value update and then serializes the field" do
      expect(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).ordered
      expect(DialogFieldSerializer).to receive(:serialize).with(dialog_field).ordered
      dialog_field.update_and_serialize_values
    end
  end

  it "does not use attr_accessor for default_value" do
    expect(described_class.new(:default_value => "test")[:default_value]).to eq("test")
  end

  describe "#update_dialog_field_responders" do
    let(:dialog_field) { described_class.create(:name => "field1", :label => "field1") }
    let(:dialog_field2) { described_class.create(:name => "field2", :label => "field2") }
    let(:dialog_field3) { described_class.create(:name => "field3", :label => "field3") }

    before do
      dialog_field.dialog_field_responders = [dialog_field3]
    end

    context "when the given list is not empty" do
      it "rebuilds the responder list based on the IDs" do
        dialog_field.update_dialog_field_responders([dialog_field2.id])
        expect(dialog_field.dialog_field_responders).to eq([dialog_field2])
      end
    end

    context "when the given list is empty" do
      it "destroys the responders" do
        dialog_field.update_dialog_field_responders([])
        expect(dialog_field.dialog_field_responders).to eq([])
      end
    end

    context "when the given list is nil" do
      it "destroys the responders without crashing" do
        dialog_field.update_dialog_field_responders(nil)
        expect(dialog_field.dialog_field_responders).to eq([])
      end
    end
  end
end
