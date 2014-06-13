require "spec_helper"

describe ActiveRecord::AttributeAccessorThatYamls do
  Vm.class_eval do
    include ActiveRecord::AttributeAccessorThatYamls
    attr_accessor_that_yamls :access1, :access2
    attr_reader_that_yamls   :read1
    attr_writer_that_yamls   :write1
  end

  it "attr_accessor_that_yamls" do
    inst = Vm.new
    inst.access1 = 1
    inst.access2 = 2
    result = YAML.load(YAML.dump(inst))
    result.access1.should == 1
    result.access2.should == 2
  end

  it "attr_reader_that_yamls" do
    inst = Vm.new
    inst.instance_variable_set("@read1", 1)
    result = YAML.load(YAML.dump(inst))
    result.read1.should == 1
  end

  it "attr_writer_that_yamls" do
    inst = Vm.new
    inst.write1 = 1
    result = YAML.load(YAML.dump(inst))
    result.instance_variable_get("@write1").should == 1
  end
end
