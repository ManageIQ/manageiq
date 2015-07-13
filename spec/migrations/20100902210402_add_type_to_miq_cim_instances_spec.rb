require "spec_helper"
require Rails.root.join("db/migrate/20100902210402_add_type_to_miq_cim_instances.rb")

describe AddTypeToMiqCimInstances do
  migration_context :up do
    let(:cim_stub) { migration_stub(:MiqCimInstance) }

    it "updates MiqCimInstance type" do
      cim = cim_stub.create!(:class_hier => "/CIM_ComputerSystem/ComputerSystem/")

      migrate

      cim.reload.type.should == "CimComputerSystem"
    end
  end
end
