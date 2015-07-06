require "spec_helper"

describe "ar_base_model extension" do
  context "with a test class" do
    before(:each) { class ::TestClass < ActiveRecord::Base; end }
    after(:each)  { Object.send(:remove_const, :TestClass) }

    it ".base_model" do
      TestClass.base_model.should == TestClass
    end

    it ".model_suffix" do
      TestClass.model_suffix.should == ""
    end

    context "with a subclass" do
      before(:each) { class ::TestClassFoo < ::TestClass; end }
      after(:each)  { Object.send(:remove_const, :TestClassFoo) }

      it ".base_model" do
        TestClassFoo.base_model.should == TestClass
      end

      it ".model_suffix" do
        TestClassFoo.model_suffix.should == "Foo"
      end
    end

  end
end
