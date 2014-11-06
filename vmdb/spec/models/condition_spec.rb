require "spec_helper"

describe Condition do
  describe ".subst" do
    context "expression with <find>" do
      before do
        @cluster = FactoryGirl.create(:ems_cluster)
        @host1 = FactoryGirl.create(:host, :ems_cluster => @cluster)
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
        Condition.subst(expr, @cluster, nil).should be_true
      end

      it "invalid expression" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2; system('ls /etc')</check></find>"
        lambda { Condition.subst(expr, @cluster, nil) }.should raise_error(SecurityError)
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
        Condition.subst(expr, @vm, nil).should == "'y'"
      end

      it "numerical type registry key data is single quoted" do
        expr = "<registry>#{@reg_num.name}</registry>"
        Condition.subst(expr, @vm, nil).should == "'0'"
      end
    end
  end
end
