require 'util/miq_winrm'
require 'Scvmm/miq_hyperv_disk'
require 'Scvmm/miq_scvmm_vm_ssa_info'

describe MiqHyperVDisk do
  before(:each) do
    @host     = "localhost"
    @user     = "user"
    @password = "password"
  end

  context "Initialize MiqHyperVDisk with a network argument" do
    it "accepts a network boolean" do
      expect { MiqHyperVDisk.new(@host, @user, @password, nil, true) }.to_not raise_error
      expect { MiqHyperVDisk.new(@host, @user, @password, nil, false) }.to_not raise_error
    end

    it "does not require a network boolean" do
      expect { MiqHyperVDisk.new(@host, @user, @password) }.to_not raise_error
    end
  end
end
