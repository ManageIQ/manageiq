require "spec_helper"

describe MiqExpression do
  describe ".get_col_type" do
    subject { described_class.get_col_type(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      subject.should == described_class.get_col_type("Vm-name")
    end

    it "with managed-field" do
      @field = "managed.location"
      subject.should == :string
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      subject.should == :string
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      subject.should == :string
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      described_class.stub(:col_type => :some_type)
      subject.should == :some_type
    end

    it "with invalid model-in_field" do
      @field = "abc-name"
      subject.should be_nil
    end

    it "with valid model.association-in_field" do
      @field = "Vm.guest_applications-vendor"
      described_class.stub(:col_type => :some_type)
      subject.should == :some_type
    end

    it "with invalid model.association-in_field" do
      @field = "abc.host-name"
      subject.should be_nil
    end

    it "with model-invalid_field" do
      @field = "Vm-abc"
      subject.should be_nil
    end

    it "with field without model" do
      @field = "storage"
      subject.should be_nil
    end
  end

  describe ".parse_field" do
    subject { described_class.parse_field(@field) }

    it "with model-field__with_pivot_table_suffix" do
      @field = "Vm-name__pv"
      subject.should == ["Vm", [], "name"]
    end

    it "with managed-field" do
      @field = "managed.location"
      subject.should == ["managed", ["location"], "managed.location"]
    end

    it "with model.managed-in_field" do
      @field = "Vm.managed-service_level"
      subject.should == ["Vm", ["managed"], "service_level"]
    end

    it "with model.last.managed-in_field" do
      @field = "Vm.host.managed-environment"
      subject.should == ["Vm", ["host", "managed"], "environment"]
    end

    it "with valid model-in_field" do
      @field = "Vm-cpu_limit"
      subject.should == ["Vm", [], "cpu_limit"]
    end

    it "with field without model" do
      @field = "storage"
      subject.should == ["storage", [], "storage"]
    end
  end
end
