RSpec.describe Condition do
  describe ".subst" do
    context "evaluation of virtual custom attributes from left and right side" do
      let(:custom_attribute_1)         { FactoryBot.create(:custom_attribute, :name => "attr_1", :value => 20) }
      let(:custom_attribute_2)         { FactoryBot.create(:custom_attribute, :name => "attr_2", :value => 30) }
      let(:name_of_custom_attribute_1) { "VmOrTemplate-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}attr_1" }
      let(:name_of_custom_attribute_2) { "VmOrTemplate-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}attr_2" }
      let!(:vm) do
        FactoryBot.create(:vm, :memory_reserve => 10, :custom_attributes => [custom_attribute_1, custom_attribute_2])
      end

      before do
        @filter_1 = MiqExpression.new(">" => {"field" => name_of_custom_attribute_1,
                                              "value" => name_of_custom_attribute_2})

        @filter_2 = MiqExpression.new(">" => {"field" => "VmOrTemplate-memory_reserve",
                                              "value" => name_of_custom_attribute_2})

        @filter_3 = MiqExpression.new(">" => {"field" => name_of_custom_attribute_1,
                                              "value" => "VmOrTemplate-memory_reserve"})
      end

      it "evaluates custom attributes on both sides" do
        condition_to_evaluate = Condition.subst(@filter_1.to_ruby(nil), vm)
        expect(condition_to_evaluate).to eq('20 > 30')
      end

      it "evaluates custom attribute on right side and integer column of VmOrTemplate on left side" do
        condition_to_evaluate = Condition.subst(@filter_2.to_ruby(nil), vm)
        expect(condition_to_evaluate).to eq('10 > 30')
      end

      it "evaluates custom attribute on left side and integer column of VmOrTemplate on right side" do
        condition_to_evaluate = Condition.subst(@filter_3.to_ruby(nil), vm)
        expect(condition_to_evaluate).to eq('20 > 10')
      end
    end

    it "doesn't access database when unchanged model is saved" do
      m = FactoryBot.create(:condition)
      expect { m.valid? }.not_to make_database_queries
    end

    context "expression with <find>" do
      let(:cluster) { FactoryBot.create(:ems_cluster) }
      let(:host1) { FactoryBot.create(:host, :ems_cluster => cluster) }
      let(:host2) { FactoryBot.create(:host, :ems_cluster => cluster) }
      before do
        @rp1 = FactoryBot.create(:resource_pool)
        @rp2 = FactoryBot.create(:resource_pool)

        cluster.with_relationship_type("ems_metadata") { cluster.add_child @rp1 }
        @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

        @vm1 = FactoryBot.create(:vm_vmware, :host => host1, :ems_cluster => cluster)
        @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }

        @vm2 = FactoryBot.create(:vm_vmware, :host => host2, :ems_cluster => cluster)
        @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }
      end

      it "valid expression" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2</check></find>"
        expect(Condition.subst(expr, cluster)).to be_truthy
      end

      it "has_one support" do
        expr = "<find><search><value ref=vm, type=string>/virtual/host/name</value> == 'XXX'</search><check mode=count><count> == 1</check></find>"
        expect(Condition.subst(expr, @vm1)).to be_truthy
      end

      it "invalid expression should not raise security error because it is now parsed and not evaluated" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2; system('ls /etc')</check></find>"
        expect { Condition.subst(expr, cluster) }.not_to raise_error
      end

      it "tests all allowed operators in find/check expression clause" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> == 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> > 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('true')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('true')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'true'</search><check mode=count><count> < 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> <= 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> != 0</check></find>"
        expect(Condition.subst(expr, cluster)).to eq('true')
      end

      it "rejects and expression with an illegal operator" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> !! 0</check></find>"
        expect { expect(Condition.subst(expr, cluster)).to eq('false') }.to raise_error(RuntimeError, "Illegal operator, '!!'")
      end
    end

    context "expression with <registry>" do
      let(:vm) { FactoryBot.create(:vm_vmware, :registry_items => [reg_num, @reg_string]) }
      let(:reg_num) { FactoryBot.create(:registry_item, :name => "HKLM\\SOFTWARE\\WindowsFirewall : EnableFirewall", :data => 0) }
      before do
        @reg_string = FactoryBot.create(:registry_item, :name => "HKLM\\SOFTWARE\\Microsoft\\Ole : EnableDCOM", :data => 'y')
      end

      it "string type registry key data is single quoted" do
        expr = "<registry>#{@reg_string.name}</registry>"
        expect(Condition.subst(expr, vm)).to eq('"y"')
      end

      it "numerical type registry key data is single quoted" do
        expr = "<registry>#{reg_num.name}</registry>"
        expect(Condition.subst(expr, vm)).to eq('"0"')
      end
    end

    it "does not change the scope for taggings when passed a Tag" do
      tag = FactoryBot.create(:tag, :name => "/managed/foo")
      vm = FactoryBot.create(:vm_vmware)
      expr = "<value ref=tag, type=text>/virtual/name</value> == \"/managed/foo\""

      described_class.subst(expr, tag)
      vm.tag_add("foo", :ns => "/managed")
      vm.reload

      expect(vm.tags).to eq([tag])
    end
  end

  describe ".do_eval" do
    it "detects true" do
      expect(Condition.do_eval("true")).to be_truthy
    end

    it "detects false" do
      expect(Condition.do_eval("false")).not_to be_truthy
    end
  end

  describe ".subst_matches?" do
    let(:vm1) { FactoryBot.build(:vm_vmware, :host => FactoryBot.build(:host, :name => "XXX")) }

    it "detects match" do
      expr = "<find><search><value ref=vm, type=string>/virtual/host/name</value> == 'XXX'</search><check mode=count> \
              <count> == 1</check></find>"
      expect(Condition.subst_matches?(expr, vm1)).to be_truthy
    end

    it "detects non-match" do
      expr = "<find><search><value ref=vm, type=string>/virtual/host/name</value> == 'YYY'</search><check mode=count> \
              <count> == 1</check></find>"
      expect(Condition.subst_matches?(expr, vm1)).not_to be_truthy
    end
  end

  describe ".import_from_hash" do
    let(:description) { "some description" }
    let(:name)        { "some name" }
    let(:guid)        { "some guid" }
    let(:expression)  { {">" => {"field" => "Vm-cpu_num", "value" => 2}} }
    let(:condition) do
      {"description" => description,
       "expression"  => MiqExpression.new(expression),
       "modifier"    => 'deny',
       "towhat"      => "Vm",
       "guid"        => guid,
       "name"        => name}
    end

    before do
      @condition, _s = Condition.import_from_hash(condition)
    end

    it "removes condition modifier and adds new record to Condition model" do
      expect(@condition.expression.exp).to eq("not" => expression)
      expect(Condition.count).to eq(1)
    end

    context "unique constrains" do
      let(:new_description) { "new description" }
      let(:new_name)        { "new name" }
      let(:new_guid)        { "new guid" }
      let(:new_expression)  { {">" => {"field" => "Vm-cpu_num", "value" => 55}} }
      let(:new_condition) do
        {"description" => new_description,
         "expression"  => MiqExpression.new(new_expression),
         "modifier"    => 'deny',
         "towhat"      => "Vm",
         "guid"        => new_guid,
         "name"        => new_name}
      end

      it "adds new records if guid, name and description for record in Hash are unique" do
        _, status = Condition.import_from_hash(new_condition)
        expect(status[:status]).to eq(:add)

        expect(Condition.count).to eq(2)
        new_condition = Condition.last
        expect(new_condition.expression.exp).to eq("not" => new_expression)
        expect(new_condition.name).to eq(new_name)
        expect(new_condition.description).to eq(new_description)
        expect(new_condition.guid).to eq(new_guid)
      end

      it "updates existing DB record if it has the same guid as record in Hash" do
        new_condition["guid"] = guid
        _, status = Condition.import_from_hash(new_condition)
        expect(status[:status]).to eq(:update)

        expect(Condition.count).to eq(1)
        new_condition = Condition.last
        expect(new_condition.expression.exp).to eq("not" => new_expression)
        expect(new_condition.name).to eq(new_name)
        expect(new_condition.description).to eq(new_description)
        expect(new_condition.guid).to eq(guid)
      end

      it "updates existing DB record if it has the same name as record in Hash but guids are different" do
        new_condition["name"] = name
        _, status = Condition.import_from_hash(new_condition)
        expect(status[:status]).to eq(:update)

        expect(Condition.count).to eq(1)
        new_condition = Condition.last
        expect(new_condition.expression.exp).to eq("not" => new_expression)
        expect(new_condition.name).to eq(name)
        expect(new_condition.description).to eq(new_description)
        expect(new_condition.guid).to eq(new_guid)
      end

      it "updates existing DB record if it has the same description as record in Hash but guids are different" do
        new_condition["description"] = description
        _, status = Condition.import_from_hash(new_condition)
        expect(status[:status]).to eq(:update)

        expect(Condition.count).to eq(1)
        new_condition = Condition.last
        expect(new_condition.expression.exp).to eq("not" => new_expression)
        expect(new_condition.name).to eq(new_name)
        expect(new_condition.description).to eq(description)
        expect(new_condition.guid).to eq(new_guid)
      end
    end
  end

  describe ".options2hash" do
    it 'returns the same record if it is descendant from Service class and passed reference is "service" ' do
      record = ServiceContainerTemplate.new
      _, result_record, _ = described_class.options2hash("ref=service", record)
      expect(result_record).to be(record)
    end
  end

  describe ".registry_data" do
    let(:name_and_value) { "HKLM\\SOFTWARE\\WindowsFirewall : EnableFirewall" }
    let(:registry_item) { FactoryBot.create(:registry_item, :name => name_and_value, :data => "100") }
    let(:vm) { FactoryBot.create(:vm_vmware, :registry_items => [registry_item]) }

    it "finds registry item record when key exists" do
      expect(described_class.registry_data(vm, 'HKLM', :key_exists => true)).to be_truthy
    end

    it "doesn't find registry item record when key exists" do
      expect(described_class.registry_data(vm, 'SOFTWARE_X', :key_exists => true)).not_to be_truthy
    end

    it "finds registry item record when value exists" do
      expect(described_class.registry_data(vm, name_and_value, :value_exists => true)).to be_truthy
    end

    it "doesn't find registry item record when value exists" do
      expect(described_class.registry_data(vm, name_and_value + "X", :value_exists => true)).not_to be_truthy
    end

    it "returns registry data" do
      expect(described_class.registry_data(vm, name_and_value, {})).to eq("100")
    end

    it "doesn't returns registry data" do
      expect(described_class.registry_data(vm, name_and_value + "X", {})).to be_nil
    end
  end
end
