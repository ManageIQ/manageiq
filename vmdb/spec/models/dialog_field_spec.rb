require "spec_helper"

describe DialogField do
  before(:each) do
    @df = FactoryGirl.create(:dialog_field, :label => 'dialog_field', :name => 'dialog_field')
  end

  it "sets default value for required attribute" do
    @df.required.should == false
  end

  it "#initialize_with_values with no initial value and no default value" do
    initial_dialog_values = {}
    @df.initialize_with_values(initial_dialog_values)
    @df.value.should be_nil
  end

  it "#initialize_with_values with no initial value and a default value" do
    initial_dialog_values = {}
    @df.default_value = "default_test"
    @df.initialize_with_values(initial_dialog_values)
    @df.value.should == "default_test"
  end

  it "#initialize_with_values with an initial value and no default value" do
    initial_dialog_values = {"dialog_field" => "test"}
    @df.initialize_with_values(initial_dialog_values)
    @df.value.should == "test"
  end

  it "#initialize_with_values with an initial value and a default value" do
    initial_dialog_values = {"dialog_field" => "test"}
    @df.default_value = "default_test"
    @df.initialize_with_values(initial_dialog_values)
    @df.value.should == "test"
  end

  it "fields named 'action' or 'controller' are invalid" do
    action_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'action')
    action_field.should_not be_valid
    controller_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'controller')
    controller_field.should_not be_valid
    foo_field = FactoryGirl.build(:dialog_field, :label => 'dialog_field', :name => 'foo')
    foo_field.should be_valid
  end

  it "supports more than 255 characters within default_value" do
    str = "0" * 10000
    @df.default_value = str
    expect { @df.save }.to_not raise_error
    @df.reload
    @df.default_value.should == str
  end
end
