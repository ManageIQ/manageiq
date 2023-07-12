describe MiqExpression::Target do
  describe ".parse" do
    subject { described_class.parse(@field)&.column_type }
    let(:string_custom_attribute) do
      FactoryBot.create(:custom_attribute,
                         :name          => "foo",
                         :value         => "string",
                         :resource_type => 'ExtManagementSystem')
    end
    let(:date_custom_attribute) do
      FactoryBot.create(:custom_attribute,
                         :name          => "foo",
                         :value         => DateTime.current,
                         :resource_type => 'ExtManagementSystem')
    end

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      expect(subject).to eq(described_class.parse("Vm-name")&.column_type)
    end

    it "with custom attribute without value_type" do
      string_custom_attribute
      @field = "ExtManagementSystem-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}foo"
      expect(subject).to eq(:string)
    end

    it "with custom attribute with value_type" do
      date_custom_attribute
      @field = "ExtManagementSystem-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}foo"
      expect(subject).to eq(:datetime)
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      expect(subject).to eq(:string)
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      expect(subject).to eq(:string)
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      expect(subject).to eq(:integer)
    end

    it "with invalid model-in_field" do
      @field = "abc-name"
      expect(subject).to be_nil
    end

    it "with valid model.association-in_field" do
      @field = "Vm.guest_applications-vendor"
      expect(subject).to eq(:string)
    end

    it "with invalid model.association-in_field" do
      @field = "abc.host-name"
      expect(subject).to be_nil
    end

    it "with model-invalid_field" do
      @field = "Vm-abc"
      expect(subject).to be_nil
    end

    it "with field without model" do
      @field = "storage"
      expect(subject).to be_nil
    end
  end

  describe "#==" do
    it "equals" do
      expect(described_class.parse("Vm-name")).to eq(MiqExpression::Field.new(Vm, [], "name"))
      expect(described_class.parse("Vm-name")).to eq(MiqExpression::Tag.new(Vm, [], "name"))
      expect(described_class.parse("Vm.host-name")).to eq(MiqExpression::Field.new(Vm, ["host"], "name"))
    end

    it "doesn't equal" do
      expect(described_class.parse("Vm.host-name")).not_to eq(MiqExpression::Field.new(Vm, [], "name"))
      expect(described_class.parse("Vm.host-name")).not_to eq("Vm-host-name")
      expect(described_class.parse("Vm-name")).not_to eql(["name", [], Vm])
    end
  end

  describe "#eql?" do
    it "equals" do
      expect(described_class.parse("Vm-name")).to eq(MiqExpression::Field.new(Vm, [], "name"))
      expect(described_class.parse("Vm.host-name")).to eq(MiqExpression::Field.new(Vm, ["host"], "name"))
    end

    it "doesn't equal" do
      expect(described_class.parse("Vm-name")).to eq(MiqExpression::Tag.new(Vm, [], "name"))
      expect(described_class.parse("Vm.host-name")).not_to eql(described_class.parse("Vm-name"))
      expect(described_class.parse("Vm.host-name")).not_to eql("Vm.host-name")
      expect(described_class.parse("Vm-name")).not_to eql(["name", [], Vm])
    end
  end
end
