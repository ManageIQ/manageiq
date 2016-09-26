describe DialogField do
  context "legacy tests" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field, :label => 'dialog_field', :name => 'dialog_field')
    end

    it "sets default value for required attribute" do
      expect(@df.required).to eq(false)
      expect(@df.visible).to eq(true)
    end

    it "fields named 'action' or 'controller' are invalid" do
      action_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'action')
      expect(action_field).not_to be_valid
      controller_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'controller')
      expect(controller_field).not_to be_valid
      foo_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'foo')
      expect(foo_field).to be_valid
    end

    it "supports more than 255 characters within default_value" do
      str = "0" * 10000
      @df.default_value = str
      expect { @df.save }.to_not raise_error
      @df.reload
      expect(@df.default_value).to eq(str)
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

    describe "#initialize_with_values" do
      it "uses #automate_key_name for extracting initial dialog values" do
        dialog_value = "dummy dialog value"
        @df.initialize_with_values(@df.automate_key_name => dialog_value)
        expect(@df.value).to eq(dialog_value)
      end

      it "initializes to nil with no initial value and no default value" do
        initial_dialog_values = {}
        @df.initialize_with_values(initial_dialog_values)
        expect(@df.value).to be_nil
      end

      it "initializes to the default value with no initial value and a default value" do
        initial_dialog_values = {}
        @df.default_value = "default_test"
        @df.initialize_with_values(initial_dialog_values)
        expect(@df.value).to eq("default_test")
      end

      it "initializes to the dialog value with a dialog value and no default value" do
        initial_dialog_values = {@df.automate_key_name => "test"}
        @df.initialize_with_values(initial_dialog_values)
        expect(@df.value).to eq("test")
      end

      it "initializes to the dialog value with a dialog value and a default value" do
        initial_dialog_values = {@df.automate_key_name => "test"}
        @df.default_value = "default_test"
        @df.initialize_with_values(initial_dialog_values)
        expect(@df.value).to eq("test")
      end
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
    end

    it "serializes the dialog field" do
      expect(DialogFieldSerializer).to receive(:serialize).with(dialog_field)
      dialog_field.update_and_serialize_values
    end
  end

  it "does not use attr_accessor for default_value" do
    expect(described_class.new(:default_value => "test")[:default_value]).to eq("test")
  end
end
