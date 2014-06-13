require "spec_helper"

describe AuthenticationMixin do
  before(:each) do
    class TestClass < ActiveRecord::Base
      self.table_name = "vms"
      include AuthenticationMixin
    end
  end

  after(:each) do
    Object.send(:remove_const, :TestClass)
  end

  shared_examples "authentication_components" do |method, required_field|
    context "##{method}" do
      let(:expected) do
        case method
        when :authentication_valid?
          false
        when :authentication_invalid?
          true
        else
          nil
        end
      end

      it "no authentication" do
        t = TestClass.new
        t.stub(:authentication_best_fit => nil)
        t.send(method).should == expected
      end

      it "no #{required_field}" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => nil))
        t.send(method).should == expected
      end

      it "blank #{required_field}" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => ""))
        t.send(method).should == expected
      end

      it "normal case" do
        t = TestClass.new
        t.stub(:authentication_best_fit => double(required_field => "test"))

        expected = case method
        when :authentication_valid?
          true
        when :authentication_invalid?
          false
        else
          "test"
        end

        t.send(method).should == expected
      end
    end
  end

  include_examples "authentication_components", :authentication_password, :password
  include_examples "authentication_components", :authentication_userid, :userid
  include_examples "authentication_components", :authentication_password_encrypted, :password_encrypted
  include_examples "authentication_components", :authentication_valid?, :userid
  include_examples "authentication_components", :authentication_invalid?, :userid

  context "required fields" do
    context "requires one field" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => :userid}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_true
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => :password}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end

    context "requires both fields" do
      it "saves when populated" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user", :password => "test_pass"}}
        options = {:required => [:userid, :password]}
        t.update_authentication(data, options)
        expect(t.has_authentication_type?(:test)).to be_true
      end

      it "raises when blank" do
        t = TestClass.new
        data    = {:test => { :userid => "test_user"}}
        options = {:required => [:userid, :password]}
        expect { t.update_authentication(data, options) }.to raise_error(ArgumentError, "password is required")
      end
    end
  end
end
