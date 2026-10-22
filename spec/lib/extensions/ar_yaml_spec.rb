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

  context "Marshal round-trip" do
    it "preserves attr_accessor_that_yamls values" do
      inst = Vm.new
      inst.access1 = 1
      inst.access2 = 2
      result = Marshal.load(Marshal.dump(inst))
      expect(result.access1).to eq(1)
      expect(result.access2).to eq(2)
    end

    it "preserves attr_reader_that_yamls values" do
      inst = Vm.new
      inst.instance_variable_set(:@read1, 1)
      result = Marshal.load(Marshal.dump(inst))
      expect(result.read1).to eq(1)
    end

    it "preserves attr_writer_that_yamls values" do
      inst = Vm.new
      inst.write1 = 1
      result = Marshal.load(Marshal.dump(inst))
      expect(result.instance_variable_get(:@write1)).to eq(1)
    end

    it "preserves AR column values alongside extra ivars" do
      inst = FactoryBot.build(:vm_vmware, :name => "myvm")
      inst.access1 = "extra"
      result = Marshal.load(Marshal.dump(inst))
      expect(result.name).to eq("myvm")
      expect(result.access1).to eq("extra")
    end

    it "preserves loaded associations alongside extra ivars" do
      host = FactoryBot.create(:host)
      inst = FactoryBot.create(:vm_vmware, :host => host)
      inst.access1 = "extra"
      inst.host # force association cache
      result = Marshal.load(Marshal.dump(inst))
      expect(result.host.id).to eq(host.id)
      expect(result.access1).to eq("extra")
    end

    it "loads cleanly when extra ivars are absent (pre-migration payload)" do
      inst = Vm.new
      # Simulate a payload marshalled before marshal_dump was defined: just the AR state
      ar_payload = inst.send(:_marshal_dump_7_1)
      result = Vm.allocate
      result.marshal_load(ar_payload)
      expect(result.access1).to be_nil
    end
  end
end
