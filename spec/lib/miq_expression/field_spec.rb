RSpec.describe MiqExpression::Field do
  describe ".tag_path_with" do
    it "returns correct path with slash in value" do
      target = described_class.parse('Vm.host-name')
      expect(target.tag_path_with('thing1/thing2')).to eq("/virtual/host/name/thing1%2fthing2")
    end

    it "returns correct path with false in value" do
      target = described_class.parse('MiqGroup.vms-disconnected')
      expect(target.tag_path_with(false)).to eq("/virtual/vms/disconnected/false")
    end
  end

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

    it "can parse the virtual custom attribute" do
      field = "ChargebackVm-virtual_custom_attribute_Application"
      expect(described_class.parse(field).column).to eq("virtual_custom_attribute_Application")
    end

    it "can parse the virtual custom attribute which represents label" do
      field = "ChargebackVm-virtual_custom_attribute_Application:SECTION:labels"
      expect(described_class.parse(field).column).to eq("virtual_custom_attribute_Application:SECTION:labels")
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

    it "will return nil when given a field with unsupported syntax" do
      field = "Vm,host+name"
      expect(described_class.parse(field)).to be_nil
    end

    it "will return nil when given a tag" do
      tag = "Vm.managed-name"
      expect(described_class.parse(tag)).to be_nil

      tag = "Vm.hosts.managed-name"
      expect(described_class.parse(tag)).to be_nil

      tag = "Vm.user_tag-name"
      expect(described_class.parse(tag)).to be_nil

      tag = "Vm.hosts.user_tag-name"
      expect(described_class.parse(tag)).to be_nil
    end

    it 'parses field with numbers in association' do
      field = 'Vm.win32_services-dependencies'
      expect(described_class.parse(field)).to have_attributes(:model        => Vm,
                                                              :associations => %w(win32_services),
                                                              :column       => 'dependencies')
    end
  end

  describe "#to_s" do
    it "renders fields in string form" do
      field = described_class.new("Vm", [], "name")
      expect(field.to_s).to eq("Vm-name")
    end

    it "can handle associations" do
      field = described_class.new("Vm", ["host"], "name")
      expect(field.to_s).to eq("Vm.host-name")
    end
  end

  describe '#report_column' do
    it 'returns the correct format for a field' do
      field = MiqExpression::Field.parse('Vm.miq_provision.miq_request-requester_name')
      expect(field.report_column).to eq('miq_provision.miq_request.requester_name')
    end
  end

  describe "#parse!" do
    it "can parse the model name" do
      field = "Vm-name"
      expect(described_class.parse(field).model).to be(Vm)
    end

    # this calls out to parse, so just needed to make sure one value worked

    it "will raise a parse error when given a field with unsupported syntax" do
      field = "Vm,host+name"
      expect { described_class.parse!(field) }.to raise_error(MiqExpression::Field::ParseError)
    end
  end

  describe "#valid?" do
    it "returns true when the column belongs to the set of column names" do
      field = described_class.new(Vm, [], "name")
      expect(field).to be_valid
    end

    it "returns true when the column belongs to the set of virtual attributes" do
      field = described_class.new(Vm, [], "platform")
      expect(field).to be_valid
    end

    it "returns true when the column is a custom attribute" do
      field = described_class.new(Vm, [], "VmOrTemplate-virtual_custom_attribute_foo")
      expect(field).to be_valid
    end

    it "returns false for non-attribute public methods" do
      field = described_class.new(Vm, [], "destroy")
      expect(field).not_to be_valid
    end

    it "returns false for non-valid associations" do
      field = described_class.new(Vm, %w[bogus association], "foo")
      expect(field).not_to be_valid
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

    it "can handle virtual associations" do
      field = described_class.new(Vm, ["processes"], "name")
      expect(field.reflections).to match([an_object_having_attributes(:klass => OsProcess)])
    end

    it "raises an error if the field has invalid associations" do
      field = described_class.new(Vm, %w(foo bar), "name")
      expect { field.reflections }.to raise_error(/One or more associations are invalid: foo, bar/)
    end
  end

  describe "#date?" do
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

  describe "#arel_table" do
    it "returns the main table when there are no associations" do
      field = described_class.new(Vm, [], "name")
      expect(field.arel_table).to eq(Vm.arel_table)
    end

    it "returns the table of the target association without an alias" do
      field = described_class.new(Vm, ["guest_applications"], "name")
      expect(field.arel_table).to eq(GuestApplication.arel_table)
      expect(field.arel_table.name).to eq(GuestApplication.arel_table.name)
    end

    it "returns the table of the target association with an alias if needed" do
      field = described_class.new(Vm, ["miq_provision_template"], "name")
      expect(field.arel_table.table_name).to eq(Vm.arel_table.table_name)
      expect(field.arel_table.name).not_to eq(Vm.arel_table.name)
    end
  end

  describe "#arel_attribute" do
    it "returns the main table when there are no associations" do
      field = described_class.new(Vm, [], "name")
      expect(field.arel_attribute).to eq(Vm.arel_attribute("name"))
    end

    it "returns the table of the target association without an alias" do
      field = described_class.new(Vm, ["guest_applications"], "name")
      expect(field.arel_attribute).to eq(GuestApplication.arel_attribute("name"))
    end

    it "returns the table of the target association with an alias if needed" do
      field = described_class.new(Vm, ["miq_provision_template"], "name")
      expect(field.arel_attribute.name).to eq("name")
      expect(field.arel_attribute.relation.name).to include("miq_provision_template")
    end
  end

  describe "#plural?" do
    it "returns false if the column is on a 'belongs_to' association" do
      field = described_class.new(Vm, ["storage"], "region_description")
      expect(field).not_to be_plural
    end

    it "returns false if the column is on a 'has_one' association" do
      field = described_class.new(Vm, ["hardware"], "guest_os")
      expect(field).not_to be_plural
    end

    it "returns true if the column is on a 'has_many' association" do
      field = described_class.new(Host, ["vms"], "name")
      expect(field).to be_plural
    end

    it "returns true if the column is on a 'has_and_belongs_to_many' association" do
      field = described_class.new(Vm, ["storages"], "name")
      expect(field).to be_plural
    end
  end

  describe "#column_type" do
    it "detects :string" do
      field = described_class.new(Vm, [], "name")
      expect(field.column_type).to eq(:string)
    end

    it "detects :integer" do
      field = described_class.new(Vm, [], "id")
      expect(field.column_type).to eq(:integer)
    end
  end

  describe "#attribute_supported_by_sql?" do
    it "detects if column is supported by sql with custom_attribute" do
      expect(MiqExpression::Field.parse("Vm-virtual_custom_attribute_example").attribute_supported_by_sql?).to be_falsey
    end

    it "detects if column is supported by sql with regular column" do
      expect(MiqExpression::Field.parse("Vm-name").attribute_supported_by_sql?).to be_truthy
    end

    it "detects if column is supported by sql through regular association" do
      expect(MiqExpression::Field.parse("Host.vms-name").attribute_supported_by_sql?).to be_truthy
    end

    it "detects if column is supported by sql through virtual association" do
      expect(MiqExpression::Field.parse("Vm.service-name").attribute_supported_by_sql?).to be_falsey
    end

    it "returns false if the associations are bogus" do
      expect(MiqExpression::Field.parse("Vm.bogus.service-name").attribute_supported_by_sql?).to be_falsey
    end
  end

  describe "#virtual_attribute?" do
    it "detects non-virtual" do
      expect(MiqExpression::Field.parse("Vm-name")).not_to be_virtual_attribute
    end

    it "detects virtual" do
      expect(MiqExpression::Field.parse("Vm-host_name")).to be_virtual_attribute
    end

    it "detects non-virtual through a relation" do
      expect(MiqExpression::Field.parse("Host.vms-name")).not_to be_virtual_attribute
    end

    it "detects virtual through a relation" do
      expect(MiqExpression::Field.parse("Host.vms-host_name")).to be_virtual_attribute
    end
  end

  describe "#sub_type" do
    it "detects :string" do
      field = described_class.new(Vm, [], "name")
      expect(field.sub_type).to eq(:string)
    end

    it "detects :integer" do
      field = described_class.new(Vm, [], "id")
      expect(field.sub_type).to eq(:integer)
    end
  end

  describe "#numeric?" do
    it "detects integer as numeric" do
      expect(MiqExpression::Field.parse("Vm-id")).to be_numeric
    end

    it "detects decimal as numeric" do
      expect(MiqExpression::Field.parse("MiqServer-memory_size")).to be_numeric
    end

    it "detects float as numeric" do
      expect(MiqExpression::Field.parse("MiqServer-percent_memory")).to be_numeric
    end

    it "detects string as non-numeric" do
      expect(MiqExpression::Field.parse("Vm-name")).not_to be_numeric
    end
  end

  describe "#reflection_supported_by_sql?" do
    it "detects if column is accessed directly" do
      expect(MiqExpression::Field.parse("Host-name")).to be_reflection_supported_by_sql
    end

    it "detects if column is accessed through regular association" do
      expect(MiqExpression::Field.parse("Host.vms-name")).to be_reflection_supported_by_sql
    end

    it "detects if column is accessed through regular virtual association" do
      expect(MiqExpression::Field.parse("Vm.service-name")).not_to be_reflection_supported_by_sql
    end
  end

  describe "#is_field?" do
    it "detects a valid field" do
      expect(MiqExpression::Field.is_field?("Vm-name")).to be_truthy
    end

    it "does not detect a string to looks like a field but isn't" do
      expect(MiqExpression::Field.is_field?("NetworkManager-team")).to be_falsey
      expect(described_class.is_field?("ManageIQ-name")).to be_falsey
    end

    it "handles regular expression" do
      expect(MiqExpression::Field.is_field?(/x/)).to be_falsey
    end
  end
end
