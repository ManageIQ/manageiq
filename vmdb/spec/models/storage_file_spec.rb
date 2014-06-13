require "spec_helper"

describe StorageFile do

  context "#is_snapshot_disk_file" do
    it "false if NOT .vmdk extension" do
      stub_file = stub(:ext_name => 'txt')
      described_class.is_snapshot_disk_file(stub_file).should be_false
    end

    it "true for hyphened-and-ending-with-delta.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => 'xx-xx-xxx-delta.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_true
    end

    it "true for delta.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => 'delta.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_true
    end

    it "true for hyphened-and-ending-with-6-digits.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => 'xxx-123456.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_true
    end

    it "true for named-with-6-digits.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => '654321.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_true
    end

    it "false for not-ending-with-delta.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => 'xxx-notdelta-but-anything.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_false
    end

    it "false for not-ending-with-6-digits.vmdk" do
      stub_file = stub(:ext_name => 'vmdk', :name => 'xxx-12345678.vmdk')
      described_class.is_snapshot_disk_file(stub_file).should be_false
    end

  end

  context "#split_file_types" do
    it "marks as a snapshot file for file delta.vmdk and hyphened-and-ending-with-delta.vmdk" do
      stub_file1 = stub(:ext_name => 'vmdk', :name => 'xxx-delta.vmdk')
      stub_file2 = stub(:ext_name => 'vmdk', :name => 'delta.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      result[:snapshot].should have(2).items

    end

    it "marks as a snapshot file for file 123456.vmdk and hyphened-and-ending-with-6-digits.vmdk" do
      stub_file1 = stub(:ext_name => 'vmdk', :name => '123456.vmdk')
      stub_file2 = stub(:ext_name => 'vmdk', :name => 'xxx-123456.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      result[:snapshot].should have(2).items
    end

    it "marks as a disk file for file hyphened-but-not-ending-with-delta.vmdk" do
      stub_file1 = stub(:ext_name => 'vmdk', :name => 'xx-xxx-notdelta.vmdk')
      stub_file2 = stub(:ext_name => 'vmdk', :name => 'anything.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      result[:disk].should have(2).items
    end

    it "marks as a disk file for file hyphened-but-not-ending-with-6-digits.vmdk" do
      stub_file1 = stub(:ext_name => 'vmdk', :name => 'x-xxx-12345678.vmdk')
      stub_file2 = stub(:ext_name => 'vmdk', :name => '1234.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      result[:disk].should have(2).items
    end

    it "marks as a snapshot file for files with extenstion .vmsd and .vmsn" do
      files = []
      %w[vmsd vmsn].each { |f| files << stub(:ext_name => f) }
      result = described_class.split_file_types(files)
      result[:snapshot].should have(2).items
    end

    it "marks as vm_ram for files with extension .nvram and .vswp" do
      files = []
      %w[nvram vswp].each { |f| files << stub(:ext_name => f) }
      result = described_class.split_file_types(files)
      result[:vm_ram].should have(2).items
    end

    it "marks as vm_misc for files with extension .vmx, .vmtx, .vmxf, .log and .hlog" do
      files = []
      %w[vmx vmtx vmxf log hlog].each { |f| files << stub(:ext_name => f) }
      result = described_class.split_file_types(files)
      result[:vm_misc].should have(5).items
    end

    it "marks as snapshot for file with extenstion .redo_whatever_else" do
      file = StorageFile.new(:ext_name => 'redo_file')
      result = described_class.split_file_types([file])
      result[:snapshot].should have(1).item
    end

    it "marks as debris for all other file types" do
      file = StorageFile.new(:ext_name => 'whatever_file')
      result = described_class.split_file_types([file])
      result[:debris].should have(1).item
    end

  end

  context "#is_file?" do
    it "true when rsc_type == file" do
      file = StorageFile.new(:rsc_type => 'file')
      file.is_file?.should be_true
    end

    it "false when rsc_type != dir" do
      file = StorageFile.new(:rsc_type => 'dir')
      file.is_file?.should be_false
    end
  end

  context "#is_directory?" do
    it "true when rsc_type == dir" do
      file = StorageFile.new(:rsc_type => 'dir')
      file.is_directory?.should be_true
    end

    it "false when rsc_type != dir" do
      file = StorageFile.new(:rsc_type => 'file')
      file.is_directory?.should be_false
    end
  end

  context "#v_size_numeric" do
    it "returns the file size" do
      file = StorageFile.new(:size => '500')
      file.v_size_numeric.should == 500
    end

    it "0 when empty" do
      file = StorageFile.new()
      file.v_size_numeric.should == 0
    end

  end

  context "#link_storage_files_to_vms" do
    it "nil when vm_ids_by_path is empty" do
      described_class.link_storage_files_to_vms(StorageFile.new(), nil).should be_false
    end

    it "saves to database when update=true" do
      file1 = FactoryGirl.create(:storage_file, :name => 'path1/test1.log')
      file2 = FactoryGirl.create(:storage_file, :name => 'path2/test2.log', :vm_or_template_id => '1002')
      vm_ids={
        "path1" => 5001,
        "path2" => 5002
      }
      described_class.link_storage_files_to_vms([file1, file2], vm_ids)
      file1.vm_or_template_id.should == 5001
      file2.vm_or_template_id.should == 5002
    end

    it "does not save to database when update=false" do
      file1 = FactoryGirl.create(:storage_file, :name => 'path1/test1.log')
      vm_ids={ "path1" => 5001 }
      described_class.link_storage_files_to_vms(file1, vm_ids, false)
      file1.vm_or_template_id.should == 5001

      file1.reload
      file1.vm_or_template_id.should == 1000
    end

  end

end

