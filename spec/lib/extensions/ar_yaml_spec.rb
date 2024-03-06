RSpec.describe ActiveRecord::AttributeAccessorThatYamls do
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
    result = YAML.safe_load(YAML.dump(inst), :permitted_classes => [Vm, ActiveModel::Attribute.const_get(:FromDatabase), ActiveModel::Attribute.const_get(:FromUser), ActiveModel::Type::String])
    expect(result.access1).to eq(1)
    expect(result.access2).to eq(2)
  end

  it "attr_reader_that_yamls" do
    inst = Vm.new
    inst.instance_variable_set(:@read1, 1)
    result = YAML.safe_load(YAML.dump(inst), :permitted_classes => [Vm, ActiveModel::Attribute.const_get(:FromDatabase), ActiveModel::Attribute.const_get(:FromUser), ActiveModel::Type::String])
    expect(result.read1).to eq(1)
  end

  it "attr_writer_that_yamls" do
    inst = Vm.new
    inst.write1 = 1
    result = YAML.safe_load(YAML.dump(inst), :permitted_classes => [Vm, ActiveModel::Attribute.const_get(:FromDatabase), ActiveModel::Attribute.const_get(:FromUser), ActiveModel::Type::String])
    expect(result.instance_variable_get(:@write1)).to eq(1)
  end
end
