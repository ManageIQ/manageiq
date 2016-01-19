describe MiqExpression do
  describe ".get_col_type" do
    subject { described_class.get_col_type(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      expect(subject).to eq(described_class.get_col_type("Vm-name"))
    end

    it "with managed-field" do
      @field = "managed.location"
      expect(subject).to eq(:string)
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
      allow(described_class).to receive_messages(:col_type => :some_type)
      expect(subject).to eq(:some_type)
    end

    it "with invalid model-in_field" do
      @field = "abc-name"
      expect(subject).to be_nil
    end

    it "with valid model.association-in_field" do
      @field = "Vm.guest_applications-vendor"
      allow(described_class).to receive_messages(:col_type => :some_type)
      expect(subject).to eq(:some_type)
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

  describe ".parse_field" do
    subject { described_class.parse_field(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      expect(subject).to eq(["Vm", [], "name"])
    end

    it "with managed-field" do
      @field = "managed.location"
      expect(subject).to eq(["managed", ["location"], "managed.location"])
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      expect(subject).to eq(["Vm", ["managed"], "service_level"])
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      expect(subject).to eq(["Vm", ["host", "managed"], "environment"])
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      expect(subject).to eq(["Vm", [], "cpu_limit"])
    end

    it "with field without model" do
      @field = "storage"
      expect(subject).to eq(["storage", [], "storage"])
    end
  end
end
