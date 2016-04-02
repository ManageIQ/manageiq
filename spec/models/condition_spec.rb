describe Condition do
  context ".seed" do
    it "should contain conditions" do
      Condition.seed
      specifications = YAML.load_file(File.join(ApplicationRecord::FIXTURE_DIR, "#{Condition.table_name}.yml"))
      specifications.reverse!
      Condition.all.each do |condition|
        spec = specifications.pop
        expect(condition).to have_attributes(spec.except(:expression, :created_on, :updated_on))

        if condition.expression.nil?
          expect(spec[:expression]).to be_nil
        else
          expect(condition.expression.exp).to eq(spec[:expression].exp)
        end
      end
    end
  end

  describe ".subst" do
    context "expression with <find>" do
      before do
        @cluster = FactoryGirl.create(:ems_cluster)
        @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster, :name => "XXX")
        @host2 = FactoryGirl.create(:host, :ems_cluster => @cluster)
        @rp1 = FactoryGirl.create(:resource_pool)
        @rp2 = FactoryGirl.create(:resource_pool)

        @cluster.with_relationship_type("ems_metadata") { @cluster.add_child @rp1 }
        @rp1.with_relationship_type("ems_metadata") { @rp1.add_child @rp2 }

        @vm1 = FactoryGirl.create(:vm_vmware, :host => @host1, :ems_cluster => @cluster)
        @vm1.with_relationship_type("ems_metadata") { @vm1.parent = @rp1 }

        @vm2 = FactoryGirl.create(:vm_vmware, :host => @host2, :ems_cluster => @cluster)
        @vm2.with_relationship_type("ems_metadata") { @vm2.parent = @rp2 }
      end

      it "valid expression" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to be_truthy
      end

      it "has_one support" do
        expr = "<find><search><value ref=vm, type=string>/virtual/host/name</value> == 'XXX'</search><check mode=count><count> == 1</check></find>"
        expect(Condition.subst(expr, @vm1, nil)).to be_truthy
      end

      it "invalid expression should not raise security error because it is now parsed and not evaluated" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2; system('ls /etc')</check></find>"
        expect { Condition.subst(expr, @cluster, nil) }.not_to raise_error
      end

      it "tests all allowed operators in find/check expression clause" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> == 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> > 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('true')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('true')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'true'</search><check mode=count><count> < 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> <= 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('false')

        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> != 0</check></find>"
        expect(Condition.subst(expr, @cluster, nil)).to eq('true')
      end

      it "rejects and expression with an illegal operator" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> !! 0</check></find>"
        expect { expect(Condition.subst(expr, @cluster, nil)).to eq('false') }.to raise_error(RuntimeError, "Illegal operator, '!!'")
      end
    end

    context "expression with <registry>" do
      before do
        @reg_num    = FactoryGirl.create(:registry_item, :name => "HKLM\\SOFTWARE\\WindowsFirewall : EnableFirewall", :data => 0)
        @reg_string = FactoryGirl.create(:registry_item, :name => "HKLM\\SOFTWARE\\Microsoft\\Ole : EnableDCOM", :data => 'y')
        @vm = FactoryGirl.create(:vm_vmware, :registry_items => [@reg_num, @reg_string])
      end

      it "string type registry key data is single quoted" do
        expr = "<registry>#{@reg_string.name}</registry>"
        expect(Condition.subst(expr, @vm, nil)).to eq('"y"')
      end

      it "numerical type registry key data is single quoted" do
        expr = "<registry>#{@reg_num.name}</registry>"
        expect(Condition.subst(expr, @vm, nil)).to eq('"0"')
      end
    end
  end
end
