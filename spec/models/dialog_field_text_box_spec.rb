describe DialogFieldTextBox do
  describe "#initialize_value_context" do
    let(:field) do
      described_class.new(
        :dynamic             => dynamic,
        :load_values_on_init => load_values_on_init,
        :show_refresh_button => show_refresh_button,
        :default_value       => "default value"
      )
    end
    let(:automate_value) { "value from automate" }
    let(:load_values_on_init) { false }
    let(:show_refresh_button) { false }

    context "when the field is dynamic" do
      let(:dynamic) { true }

      before do
        allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).and_return(automate_value)
      end

      context "when show_refresh_button is true" do
        let(:show_refresh_button) { true }

        context "when load_values_on_init is true" do
          let(:load_values_on_init) { true }

          it "sets the value to the automate value" do
            field.initialize_value_context
            expect(field.instance_variable_get(:@value)).to eq("value from automate")
          end
        end

        context "when load_values_on_init is false" do
          let(:load_values_on_init) { false }

          it "uses the default value" do
            field.initialize_value_context
            expect(field.instance_variable_get(:@value)).to eq("default value")
          end
        end
      end

      context "when show_refresh_button is false" do
        let(:show_refresh_button) { false }

        it "sets the value to the automate value" do
          field.initialize_value_context
          expect(field.instance_variable_get(:@value)).to eq("value from automate")
        end
      end
    end

    context "when the field is not dynamic" do
      let(:dynamic) { false }

      it "uses the default value" do
        field.initialize_value_context
        expect(field.instance_variable_get(:@value)).to eq("default value")
      end
    end
  end

  describe "#initial_values" do
    let(:dialog_field) { described_class.new }

    it "returns a blank string" do
      expect(dialog_field.initial_values).to eq("")
    end
  end

  context "dialog field text box without options hash" do
    let(:df) { FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field') }

    it "#protected?" do
      expect(df).not_to be_protected
    end

    it "#protected=" do
      df.protected = true
      expect(df).to be_protected
    end
  end

  context "dialog field text box without protected field" do
    let(:df) { FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field', :options => {:protected => false}) }

    it "#protected?" do
      expect(df).not_to be_protected
    end

    it "#automate_key_name" do
      expect(df.automate_key_name).to eq("dialog_test field")
    end
  end

  context "dialog field text box with protected field" do
    let(:df) { FactoryGirl.build(:dialog_field_text_box, :label   => 'test field', :name    => 'test field', :options => {:protected => true}) }

    it "#protected?" do
      expect(df).to be_protected
    end

    it "#automate_output_value" do
      df.value = "test string"

      expect(df.automate_output_value).to be_encrypted("test string")
    end

    it "#protected? with reset" do
      df.value = "test string"

      df.options[:protected] = false
      expect(df).not_to be_protected
      expect(df.automate_output_value).to eq("test string")
    end

    it "#automate_key_name" do
      expect(df.automate_key_name).to eq("password::dialog_test field")
    end

    context "when the value is already encrypted" do
      before do
        allow(MiqPassword).to receive(:encrypted?).and_return(true)
      end

      it "does not double encrypt it" do
        df.value = MiqPassword.encrypt("test")

        expect(df.automate_output_value).to be_encrypted("test")
      end
    end
  end

  context "validation" do
    let(:df) { FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field') }

    describe "#validate_field_data" do
      let(:dt) { double('DialogTab', :label => 'tab') }
      let(:dg) { double('DialogGroup', :label => 'group') }

      context "when validation rule is present" do
        before do
          df.validator_type = 'regex'
          df.validator_rule = '[aA]bc'
          df.required = true
        end

        it "returns nil when no error is detected" do
          df.value = 'Abc'
          expect(df.validate_field_data(dt, dg)).to be_nil
        end

        it "returns an error when the value doesn't match the regex rule" do
          df.value = 123
          expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is invalid')
        end

        it "returns an error when no value is set" do
          df.value = nil
          expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is required')
        end

        context "when the validation rule is supposed to match a set of integers" do
          before do
            df.validator_rule = '916'
          end

          context "when the value is a string" do
            it "returns nil" do
              df.value = '916'
              expect(df.validate_field_data(dt, dg)).to be_nil
            end
          end

          context "when the value is an integer" do
            it "returns nil" do
              df.value = 916
              expect(df.validate_field_data(dt, dg)).to be_nil
            end
          end
        end
      end

      context "when validation rule is not present" do
        it "accepts any value" do
          ['abc', '123', nil].each do |value|
            df.value = value
            expect(df.validate_field_data(dt, dg)).to be_nil
          end
        end

        it "returns an error when a required value is nil" do
          df.value = nil
          df.required = true
          expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is required')
        end

        context "when data type is integer" do
          before { df.data_type = 'integer' }

          context "when the value is a number string" do
            it "returns nil" do
              df.value = '123'
              expect(df.validate_field_data(dt, dg)).to be_nil
            end
          end

          context "when the value is not a number string" do
            it "returns an error" do
              df.value = 'a12'
              expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field must be an integer')
            end
          end

          context "when the value is an actual integer" do
            it "returns nil" do
              df.value = 123
              expect(df.validate_field_data(dt, dg)).to be_nil
            end
          end
        end
      end
    end
  end

  describe "#value" do
    let(:dialog_field) { described_class.new(:value => value, :data_type => data_type) }

    context "when the value is nil" do
      let(:value) { nil }

      context "when the data_type is integer" do
        let(:data_type) { "integer" }

        it "returns nil" do
          expect(dialog_field.value).to be_nil
        end
      end

      context "when the data_type is string" do
        let(:data_type) { "string" }

        it "returns nil" do
          expect(dialog_field.value).to be_nil
        end
      end
    end

    context "when the value is not nil" do
      let(:value) { "test" }

      context "when the data_type is integer" do
        let(:data_type) { "integer" }

        it "returns an integer converted value" do
          expect(dialog_field.value).to eq(0)
        end
      end

      context "when the data_type is string" do
        let(:data_type) { "string" }

        it "returns the string" do
          expect(dialog_field.value).to eq("test")
        end
      end
    end
  end

  describe "#script_error_values" do
    let(:dialog_field) { described_class.new }

    it "returns the script error values" do
      expect(dialog_field.script_error_values).to eq("<Script error>")
    end
  end

  describe "#normalize_automate_values" do
    let(:dialog_field) { described_class.new }
    let(:automate_hash) do
      {
        "data_type"      => "datatype",
        "value"          => value,
        "protected"      => true,
        "description"    => "description",
        "required"       => true,
        "read_only"      => true,
        "validator_type" => "regex",
        "validator_rule" => "rule"
      }
    end

    shared_examples_for "DialogFieldTextBox#normalize_automate_values" do
      before do
        dialog_field.normalize_automate_values(automate_hash)
      end

      it "sets the protected" do
        expect(dialog_field.protected?).to be_truthy
      end

      it "sets the required" do
        expect(dialog_field.required).to be_truthy
      end

      it "sets the description" do
        expect(dialog_field.description).to eq("description")
      end

      it "sets the read_only" do
        expect(dialog_field.read_only).to be_truthy
      end

      it "sets the validator type" do
        expect(dialog_field.validator_type).to eq("regex")
      end

      it "sets the validator rule" do
        expect(dialog_field.validator_rule).to eq("rule")
      end
    end

    context "when the automate hash does not have a value" do
      let(:value) { nil }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "returns the initial values" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("")
      end
    end

    context "when the automate hash has a value" do
      let(:value) { '123' }

      it_behaves_like "DialogFieldTextBox#normalize_automate_values"

      it "returns the value in string format" do
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("123")
      end
    end
  end

  describe "#sample_text" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :value => value, :default_value => "defaultvalue") }

    context "when the dialog is dynamic" do
      let(:dynamic) { true }
      let(:value) { "somevalue" }

      it "returns 'Sample Text'" do
        expect(dialog_field.sample_text).to eq("Sample Text")
      end
    end

    context "when the dialog is not dynamic" do
      let(:dynamic) { false }

      context "when the dialog has a value" do
        let(:value) { "somevalue" }

        it "returns the value" do
          expect(dialog_field.sample_text).to eq("somevalue")
        end
      end

      context "when the dialog does not have a value" do
        let(:value) { nil }

        it "returns the default value" do
          expect(dialog_field.sample_text).to eq("defaultvalue")
        end
      end
    end
  end

  describe "#refresh_json_value" do
    let(:dialog_field) { described_class.new(:value => "test", :read_only => true) }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("processor")
    end

    it "returns the values from the value processor" do
      expect(dialog_field.refresh_json_value).to eq(:text => "processor", :read_only => true, :visible => true)
    end

    it "assigns the processed value to value" do
      dialog_field.refresh_json_value
      expect(dialog_field.value).to eq("processor")
    end
  end

  describe "#trigger_automate_value_updates" do
    let(:dialog_field) { described_class.new }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return(
        "processed values"
      )
    end

    it "returns the values from automate" do
      expect(dialog_field.trigger_automate_value_updates).to eq("processed values")
    end
  end

  describe "#automate_output_value" do
    let(:dialog_field) do
      described_class.new(:value => "12test", :data_type => data_type, :protected => protected_attr)
    end

    context "when the data type is a string" do
      let(:data_type) { "string" }

      context "when it is protected" do
        let(:protected_attr) { true }

        before do
          allow(MiqPassword).to receive(:encrypt).with("12test").and_return("lol")
        end

        it "returns the encrypted value" do
          expect(dialog_field.automate_output_value).to eq("lol")
        end
      end

      context "when it is not protected" do
        let(:protected_attr) { false }

        it "returns the un-encrypted value" do
          expect(dialog_field.automate_output_value).to eq("12test")
        end
      end
    end

    context "when the data type is an integer" do
      let(:data_type) { "integer" }

      context "when it is protected" do
        let(:protected_attr) { true }

        before do
          allow(MiqPassword).to receive(:encrypt).with("12test").and_return("lol")
        end

        it "returns the encrypted value" do
          expect(dialog_field.automate_output_value).to eq("lol")
        end
      end

      context "when it is not protected" do
        let(:protected_attr) { false }

        it "converts the value to an integer" do
          expect(dialog_field.automate_output_value).to eq(12)
        end
      end

      context "when there is no value" do
        let(:nil_dialog_field) { described_class.new(:data_type => data_type) }

        it "does not convert nil value to zero" do
          expect(nil_dialog_field.automate_output_value).to be_nil
        end
      end
    end
  end
end
