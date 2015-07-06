require "spec_helper"
require Rails.root.join("db/migrate/20100902190255_convert_smis_class_hier_to_string.rb")

describe ConvertSmisClassHierToString do
  migration_context :up do
    let(:cim_stub) { migration_stub(:MiqCimInstance) }

    it "updates MiqCimInstance class_hier to string" do
      cim = cim_stub.create!(:class_hier => YAML.dump(["CIM_ComputerSystem", "ComputerSystem"]))

      migrate

      cim.reload.class_hier.should == "/CIM_ComputerSystem/ComputerSystem/"
    end
  end

  migration_context :down do
    let(:cim_stub) { migration_stub(:MiqCimInstance) }

    it "updates MiqCimInstance class_hier to string" do
      cim = cim_stub.create!(:class_hier => "/CIM_ComputerSystem/ComputerSystem/")

      migrate

      cim.reload.class_hier.should == YAML.dump(["CIM_ComputerSystem", "ComputerSystem"])
    end
  end
end
