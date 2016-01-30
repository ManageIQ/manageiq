describe DialogFieldTextBox do
  context "dialog field text box without options hash" do
    before do
      @df = FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field')
    end

    it "#protected?" do
      expect(@df).not_to be_protected
    end

    it "#protected=" do
      @df.protected = true
      expect(@df).to be_protected
    end

    describe "#initialize_with_values" do
      it "decrypts protected automate dialog values" do
        password = "test"
        @df.protected = true
        @df.initialize_with_values(@df.automate_key_name => MiqPassword.encrypt(password))
        expect(@df.value).to eq(password)
      end
    end
  end

  context "dialog field text box without protected field" do
    before do
      @df = FactoryGirl.build(
        :dialog_field_text_box,
        :label   => 'test field',
        :name    => 'test field',
        :options => {:protected => false}
      )
    end

    it "#protected?" do
      expect(@df).not_to be_protected
    end

    it "#automate_key_name" do
      expect(@df.automate_key_name).to eq("dialog_test field")
    end
  end

  context "dialog field text box with protected field" do
    before do
      @df = FactoryGirl.build(
        :dialog_field_text_box,
        :label   => 'test field',
        :name    => 'test field',
        :options => {:protected => true}
      )
    end

    it "#protected?" do
      expect(@df).to be_protected
    end

    it "#automate_output_value" do
      @df.value = "test string"

      expect(@df.automate_output_value).to be_encrypted("test string")
    end

    it "#protected? with reset" do
      @df.value = "test string"

      @df.options[:protected] = false
      expect(@df).not_to be_protected
      expect(@df.automate_output_value).to eq("test string")
    end

    it "#automate_key_name" do
      expect(@df.automate_key_name).to eq("password::dialog_test field")
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
          df.value = '123'
          expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is invalid')
        end

        it "returns an error when no value is set" do
          df.value = nil
          expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is required')
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

          it "returns nil when the value is a number" do
            df.value = '123'
            expect(df.validate_field_data(dt, dg)).to be_nil
          end

          it "returns an error when the value is not a number" do
            df.value = 'a12'
            expect(df.validate_field_data(dt, dg)).to eq('tab/group/test field is invalid')
          end
        end
      end
    end
  end

  describe "#value" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic, :value => value) }

    context "when the dialog field is dynamic" do
      let(:dynamic) { true }

      context "when the dialog field has a value already" do
        let(:value) { "test" }

        it "returns the current value" do
          expect(dialog_field.value).to eq("test")
        end
      end

      context "when the dialog field does not have a value" do
        let(:value) { "" }

        before do
          allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("processor")
        end

        it "returns the values from the value processor" do
          expect(dialog_field.value).to eq("processor")
        end
      end
    end

    context "when the dialog field is not dynamic" do
      let(:dynamic) { false }
      let(:value) { "test" }

      it "returns the current value" do
        expect(dialog_field.value).to eq("test")
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
        expect(dialog_field.normalize_automate_values(automate_hash)).to eq("<None>")
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
    let(:dialog_field) { described_class.new(:value => "test") }

    before do
      allow(DynamicDialogFieldValueProcessor).to receive(:values_from_automate).with(dialog_field).and_return("processor")
    end

    it "returns the values from the value processor" do
      expect(dialog_field.refresh_json_value).to eq(:text => "processor")
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
end
