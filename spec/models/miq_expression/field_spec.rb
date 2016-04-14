require "rails_helper"

RSpec.describe MiqExpression::Field do
  describe ".parse" do
    it "can parse the model name" do
      field = "Vm-name"
      expect(described_class.parse(field).model).to be(Vm)
    end

    it "can parse a namespaced model name" do
      field = "ManageIQ::Providers::CloudManager::Vm-name"
      expect(described_class.parse(field).model).to be(ManageIQ::Providers::CloudManager::Vm)
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

    it "can parse the associations when there is none present" do
      field = "Vm-name"
      expect(described_class.parse(field).associations).to be_empty
    end

    it "can parse the associations when there is one present" do
      field = "Vm.host-name"
      expect(described_class.parse(field).associations).to eq(["host"])
    end

    it "can parse the associations when there are many present" do
      field = "Vm.host.hardware-id"
      expect(described_class.parse(field).associations).to eq(%w(host hardware))
    end

    it "will raise a parse error when given a field with unsupported syntax" do
      field = "Vm,host+name"
      expect { described_class.parse(field) }.to raise_error(MiqExpression::Field::ParseError)
    end
  end

  describe "#reflections" do
    it "returns an empty array if there are no associations" do
      field = described_class.new(Vm, [], "name")
      expect(field.reflections).to be_empty
    end

    it "returns the reflections of fields with one association" do
      field = described_class.new(Vm, ["host"], "name")
      expect(field.reflections).to match([an_object_having_attributes(:klass => Host)])
    end

    it "returns the reflections of fields with multiple associations" do
      field = described_class.new(Vm, %w(host hardware), "guest_os")
      expect(field.reflections).to match([an_object_having_attributes(:klass => Host),
                                          an_object_having_attributes(:klass => Hardware)])
    end

    it "can handle associations which override the class name" do
      field = described_class.new(Vm, ["users"], "name")
      expect(field.reflections).to match([an_object_having_attributes(:klass => Account)])
    end

    it "raises an error if the field has virtual associations" do
      field = described_class.new(Vm, ["processes"], "name")
      expect { field.reflections }.to raise_error(/One or more associations are invalid: processes/)
    end

    it "raises an error if the field has invalid associations" do
      field = described_class.new(Vm, %w(foo bar), "name")
      expect { field.reflections }.to raise_error(/One or more associations are invalid: foo, bar/)
    end
  end

  describe "#date?" do
    it "returns true for fields of column type :date" do
      field = described_class.new(Vm, [], "retires_on")
      expect(field).to be_date
    end

    it "returns false for fields of column type other than :date" do
      field = described_class.new(Vm, [], "name")
      expect(field).not_to be_date
    end
  end

  describe "#datetime?" do
    it "returns true for fields of column type :datetime" do
      field = described_class.new(Vm, [], "created_on")
      expect(field).to be_datetime
    end

    it "returns false for fields of column type other than :datetime" do
      field = described_class.new(Vm, [], "name")
      expect(field).not_to be_datetime
    end

    it "returns true for a :datetime type column on an association" do
      field = described_class.new(Vm, ["guest_applications"], "install_time")
      expect(field).to be_datetime
    end
  end

  describe "#target" do
    it "returns the model when there are no associations" do
      field = described_class.new(Vm, [], "name")
      expect(field.target).to eq(Vm)
    end

    it "returns the model of the target association if there are associations" do
      field = described_class.new(Vm, ["guest_applications"], "name")
      expect(field.target).to eq(GuestApplication)
    end
  end
end
