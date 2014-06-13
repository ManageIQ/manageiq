require "spec_helper"

describe DialogFieldTextBox do

  context "dialog field text box without options hash" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_text_box, :label => 'test field', :name => 'test field')
    end

    it "#protected?" do
      @df.should_not be_protected
    end

    it "#protected=" do
      @df.protected = true
      @df.should be_protected
    end

  end

  context "dialog field text box without protected field" do
    before(:each) do
      @df = FactoryGirl.create(:dialog_field_text_box, :label => 'test field', :name => 'test field', :options => {:protected => false} )
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
      @df = FactoryGirl.create(:dialog_field_text_box, :label => 'test field', :name => 'test field', :options => {:protected => true} )
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

end
