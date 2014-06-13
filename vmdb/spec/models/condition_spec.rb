require "spec_helper"

describe Condition do
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

    context ".subst" do
      it "valid expression" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2</check></find>"
        Condition.subst(expr, @cluster, nil).should be_true
      end

      it "invalid expression" do
        expr = "<find><search><value ref=emscluster, type=boolean>/virtual/vms/active</value> == 'false'</search><check mode=count><count> >= 2; system('ls /etc')</check></find>"
        lambda { Condition.subst(expr, @cluster, nil) }.should raise_error(SecurityError)
      end
    end
end
