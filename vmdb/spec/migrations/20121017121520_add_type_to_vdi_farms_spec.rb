require "spec_helper"
require Rails.root.join("db/migrate/20121017121520_add_type_to_vdi_farms.rb")

describe AddTypeToVdiFarms do
  migration_context :up do
    let(:vdi_farm_stub)  { migration_stub(:VdiFarm) }

    it "updates vdi farms with vendor = citrix to VdiFarmCitrix type" do
      citrix = vdi_farm_stub.create!(:vendor => "citrix")

      migrate

      citrix.reload.type.should eq "VdiFarmCitrix"
    end

    it "updates vdi farms with vendor != citrix to VdiFarmVmware" do
      vmware = vdi_farm_stub.create!(:vendor => "vmware")

      migrate

      vmware.reload.type.should eq "VdiFarmVmware"
    end
  end
end
