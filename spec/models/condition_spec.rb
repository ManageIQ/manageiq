describe Condition do
  describe ".subst" do
    context "evaluation of virtual custom attributes from left and right side" do
      let(:custom_attribute_1)         { FactoryGirl.create(:custom_attribute, :name => "attr_1", :value => 20) }
      let(:custom_attribute_2)         { FactoryGirl.create(:custom_attribute, :name => "attr_2", :value => 30) }
      let(:name_of_custom_attribute_1) { "VmOrTemplate-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}attr_1" }
      let(:name_of_custom_attribute_2) { "VmOrTemplate-#{CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX}attr_2" }
      let!(:vm) do
        FactoryGirl.create(:vm, :memory_reserve => 10, :custom_attributes => [custom_attribute_1, custom_attribute_2])
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

    context "expression with <find>" do
      let(:cluster) { FactoryGirl.create(:ems_cluster) }
      let(:host1) { FactoryGirl.create(:host, :ems_cluster => cluster) }
      let(:host2) { FactoryGirl.create(:host, :ems_cluster => cluster) }
      before do
        @rp1 = FactoryGirl.create(:resource_pool)
        @rp2 = FactoryGirl.create(:resource_pool)

        cluster.with_relationship_type("ems_metadata") { cluster.add_child @rp1 }
        @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

        @vm1 = FactoryGirl.create(:vm_vmware, :host => host1, :ems_cluster => cluster)
        @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }

        @vm2 = FactoryGirl.create(:vm_vmware, :host => host2, :ems_cluster => cluster)
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
      let(:vm) { FactoryGirl.create(:vm_vmware, :registry_items => [reg_num, @reg_string]) }
      let(:reg_num) { FactoryGirl.create(:registry_item, :name => "HKLM\\SOFTWARE\\WindowsFirewall : EnableFirewall", :data => 0) }
      before do
        @reg_string = FactoryGirl.create(:registry_item, :name => "HKLM\\SOFTWARE\\Microsoft\\Ole : EnableDCOM", :data => 'y')
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
      tag = FactoryGirl.create(:tag, :name => "/managed/foo")
      vm = FactoryGirl.create(:vm_vmware)
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
    let(:vm1) { FactoryGirl.build(:vm_vmware, :host => FactoryGirl.build(:host, :name => "XXX")) }

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
    it "removes condition modifier" do
      cond_hash = {
        "description" => "test condition",
        "expression"  => MiqExpression.new(">" => {"field" => "Vm-cpu_num", "value" => 2}),
        "modifier"    => 'deny',
        "towhat"      => "Vm"
      }
      condition, _s = Condition.import_from_hash(cond_hash)
      expect(condition.expression.exp).to eq("not" => {">" => {"field" => "Vm-cpu_num", "value" => 2}})
    end
  end
end
