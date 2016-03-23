shared_examples_for "MiqVm instance methods" do
  describe ".rootTrees" do
    it "should return an array", :ex_tag => 1 do
      expect(miq_vm.rootTrees).to be_kind_of(Array)
    end

    it "should return an array of the expected length", :ex_tag => 2 do
      expect(miq_vm.rootTrees.length).to eq(expected_num_roots)
    end

    it "should return an array of MiqMountManager objects", :ex_tag => 3 do
      expect(miq_vm.rootTrees.first).to be_kind_of(MiqMountManager)
    end

    it "should return a MiqMountManager for the expected guest OS", :ex_tag => 4 do
      expect(miq_vm.rootTrees.first.guestOS).to eq(expected_guest_os)
    end

    it "should return the expected number of mounted filesystems", :ex_tag => 5 do
      expect(miq_vm.rootTrees.first.fileSystems.length).to eq(expected_num_fs)
    end

    it "should return the expected types of mounted filesystems", :ex_tag => 6 do
      fs_types = miq_vm.rootTrees.first.fileSystems.collect{ |fsd| fsd.fs.fsType }
      expect(fs_types).to match_array(expected_num_fs_types)
    end

    it "should return the expected mount points", :ex_tag => 7 do
      mount_points = miq_vm.rootTrees.first.fileSystems.collect{ |fsd| fsd.mountPoint }
      expect(mount_points).to match_array(expected_mount_points)
    end
  end
end
