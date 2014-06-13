require "spec_helper"

describe CustomAttributeMixin do
  before do
    class TestClass < ActiveRecord::Base
      self.table_name = "vms"
      include CustomAttributeMixin
    end

    @supported_factories = [:vm_redhat, :host]
  end

  after do
    Object.send(:remove_const, "TestClass")
  end

  it "defines #miq_custom_keys" do
    TestClass.new.should respond_to(:miq_custom_keys)
  end

  it "defines #miq_custom_get" do
    TestClass.new.should respond_to(:miq_custom_get)
  end

  it "defines #miq_custom_set" do
    TestClass.new.should respond_to(:miq_custom_set)
  end

  it "defines custom getter and setter methods" do
    t = TestClass.new
    (1..9).each do |custom_id|
      custom_str = "custom_#{custom_id}"
      getter     = custom_str.to_sym
      setter     = "#{custom_str}=".to_sym

      t.should respond_to(getter)
      t.should respond_to(setter)
    end
  end

  it "#miq_custom_keys" do
    TestClass.new.miq_custom_keys.should == []
    @supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      object.miq_custom_keys.should == []

      key  = "foo"
      FactoryGirl.create(:miq_custom_attribute,
                          :resource_type => object.class.base_class.name,
                          :resource_id   => object.id,
                          :name          => key,
                          :value         => "bar")

      object.reload.miq_custom_keys.should == [key]

      key2 = "foobar"
      FactoryGirl.create(:miq_custom_attribute,
                          :resource_type => object.class.base_class.name,
                          :resource_id   => object.id,
                          :name          => key2,
                          :value         => "bar")
      object.reload.miq_custom_keys.should have_same_elements([key, key2])
    end
  end

  it "#miq_custom_set" do
    @supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      key    = "foo"
      value  = "bar"
      source = 'EVM'

      CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first.should be_nil

      object.miq_custom_set(key, "")
      CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first.should be_nil

      object.miq_custom_set(key, value)
      CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key,
        :value         => value).first.should_not be_nil

      object.miq_custom_set(key, "")
      CustomAttribute.where(
        :resource_type => object.class.base_class.name,
        :resource_id   => object.id,
        :source        => source,
        :name          => key).first.should be_nil
    end
  end

  it "#miq_custom_get" do
    @supported_factories.each do |factory_name|
      object = FactoryGirl.create(factory_name)

      key   = "foo"
      value = "bar"

      object.miq_custom_get(key).should be_nil

      FactoryGirl.create(:miq_custom_attribute,
                          :resource_type => object.class.base_class.name,
                          :resource_id   => object.id,
                          :name          => key,
                          :value         => value)

      object.reload.miq_custom_get(key).should == value
    end
  end


end
