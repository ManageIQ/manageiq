require "rails_helper"

RSpec.describe MiqExpression::Field do
  describe ".parse" do
    it "can parse the model name" do
      field = "Vm-name"
      expect(described_class.parse(field).model).to be(Vm)
    end

    it "can parse the model name with associations present" do
      field = "Vm.host-name"
      expect(described_class.parse(field).model).to be(Vm)
    end

    it "can parse the column name" do
      field = "Vm-name"
      expect(described_class.parse(field).column).to eq("name")
    end

    it "can parse the column name with associations present" do
      field = "Vm.host-name"
      expect(described_class.parse(field).column).to eq("name")
    end

    it "can parse the column name with pivot table suffix" do
      field = "Vm-name__pv"
      expect(described_class.parse(field).column).to eq("name")
    end

    it "can parse column names with snakecase" do
      field = "Vm-last_scan_on"
      expect(described_class.parse(field).column).to eq("last_scan_on")
    end

    it "can parse the association when there is none present" do
      field = "Vm-name"
      expect(described_class.parse(field).association).to be_nil
    end

    it "can parse the association when there is one present" do
      field = "Vm.host-name"
      expect(described_class.parse(field).association).to eq("host")
    end

    it "will raise a parse error if there are many associations present" do
      field = "Vm.host.hardware-id"
      expect { described_class.parse(field) }.to raise_error(MiqExpression::Field::ParseError)
    end
  end

  describe "#date?" do
    it "returns true for fields of column type :date" do
      field = described_class.new(Vm, nil, "retires_on")
      expect(field).to be_date
    end

    it "returns false for fields of column type other than :date" do
      field = described_class.new(Vm, nil, "name")
      expect(field).not_to be_date
    end
  end

  describe "#datetime?" do
    it "returns true for fields of column type :datetime" do
      field = described_class.new(Vm, nil, "created_on")
      expect(field).to be_datetime
    end

    it "returns false for fields of column type other than :datetime" do
      field = described_class.new(Vm, nil, "name")
      expect(field).not_to be_datetime
    end

    it "returns true for a :datetime type column on an association" do
      field = described_class.new(Vm, "guest_applications", "install_time")
      expect(field).to be_datetime
    end
  end

  describe "#table_name" do
    it "returns the table name of the model when there is no association" do
      field = described_class.new(Vm, nil, "name")
      expect(field.table_name).to eq("vms")
    end

    it "returns the table name of the target association if there is an association" do
      field = described_class.new(Vm, "guest_applications", "name")
      expect(field.table_name).to eq("guest_applications")
    end
  end
end
