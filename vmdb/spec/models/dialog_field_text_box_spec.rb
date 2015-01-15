require "spec_helper"

describe DialogFieldTextBox do
  context "dialog field text box without options hash" do
    before(:each) do
      @df = FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field')
    end

    it "#protected?" do
      @df.should_not be_protected
    end

    it "#protected=" do
      @df.protected = true
      @df.should be_protected
    end

    describe "#initialize_with_values" do
      it "decrypts protected automate dialog values" do
        password = "test"
        @df.protected = true
        @df.initialize_with_values(@df.automate_key_name => MiqPassword.encrypt(password))
        @df.value.should == password
      end
    end
  end

  context "dialog field text box without protected field" do
    before(:each) do
      @df = FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field', :options => {:protected => false} )
    end

    it "#protected?" do
      @df.should_not be_protected
    end

    it "#automate_key_name" do
      @df.automate_key_name.should == "dialog_test field"
    end
  end

  context "dialog field text box with protected field" do
    before(:each) do
      @df = FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field', :options => {:protected => true} )
    end

    it "#protected?" do
      @df.should be_protected
    end

    it "#automate_output_value" do
      @df.value = "test string"

      expect(@df.automate_output_value).to be_encrypted("test string")
    end

    it "#protected? with reset" do
      @df.value = "test string"

      @df.options[:protected] = false
      @df.should_not be_protected
      @df.automate_output_value.should == "test string"
    end

    it "#automate_key_name" do
      @df.automate_key_name.should == "password::dialog_test field"
    end

  end

  context "validation" do
    let(:df) { FactoryGirl.build(:dialog_field_text_box, :label => 'test field', :name => 'test field') }

    context "#validate" do
      let(:dt) { active_record_instance_double('DialogTab', :label => 'tab') }
      let(:dg) { active_record_instance_double('DialogGroup', :label => 'group') }

      before(:each) do
        df.validator_type = 'regex'
        df.validator_rule = '[aA]bc'
        df.required = true
      end

      it "should return nil when no error is detected" do
        df.value = 'Abc'
        df.validate(dt, dg).should be_nil
      end

      it "should return an error when the value doesn't match the regex rule" do
        df.value = '123'
        df.validate(dt, dg).should == 'tab/group/test field is invalid'
      end

      it "should return an error when a required value is not provided" do
        df.value = ''
        df.validator_rule = ''
        df.validate(dt, dg).should == 'tab/group/test field is required'
      end
    end
  end

  describe "#refresh_button_pressed" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    context "when the dialog field is dynamic" do
      let(:dynamic) { true }

      before do
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return("processor")

        dialog_field.default_value = "some value"
      end

      it "resets default value to nil" do
        dialog_field.refresh_button_pressed
        expect(dialog_field.default_value).to be_nil
      end

      it "returns the values from the value processor" do
        expect(dialog_field.refresh_button_pressed).to eq("processor")
      end
    end

    context "when the dialog field is not dynamic" do
      let(:dynamic) { false }

      before do
        dialog_field.default_value = "some value"
        dialog_field.update_values("test")
      end

      it "resets default value to nil" do
        dialog_field.refresh_button_pressed
        expect(dialog_field.default_value).to be_nil
      end

      it "returns the current values" do
        expect(dialog_field.refresh_button_pressed).to eq("test")
      end
    end
  end

  describe "#values" do
    let(:dialog_field) { described_class.new(:dynamic => dynamic) }

    before do
      dialog_field.update_values("test")
    end

    context "when the dialog field is dynamic" do
      let(:dynamic) { true }

      before do
        DynamicDialogFieldValueProcessor.stub(:values_from_automate).with(dialog_field).and_return("processor")
      end

      it "returns the values from the value processor" do
        expect(dialog_field.values).to eq("processor")
      end
    end

    context "when the dialog field is not dynamic" do
      let(:dynamic) { false }

      it "returns the current value" do
        expect(dialog_field.values).to eq("test")
      end
    end
  end

  describe "#script_error_values" do
    let(:dialog_field) { described_class.new }

    it "returns the script error values" do
      expect(dialog_field.script_error_values).to eq("<Script error>")
    end
  end
end
