RSpec.describe StorageFile do
  context "#is_snapshot_disk_file" do
    it "false if NOT .vmdk extension" do
      stub_file = double(:ext_name => 'txt')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_falsey
    end

    it "true for hyphened-and-ending-with-delta.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => 'xx-xx-xxx-delta.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_truthy
    end

    it "true for delta.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => 'delta.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_truthy
    end

    it "true for hyphened-and-ending-with-6-digits.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => 'xxx-123456.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_truthy
    end

    it "true for named-with-6-digits.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => '654321.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_truthy
    end

    it "false for not-ending-with-delta.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => 'xxx-notdelta-but-anything.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_falsey
    end

    it "false for not-ending-with-6-digits.vmdk" do
      stub_file = double(:ext_name => 'vmdk', :name => 'xxx-12345678.vmdk')
      expect(described_class.is_snapshot_disk_file(stub_file)).to be_falsey
    end
  end

  context "#split_file_types" do
    it "marks as a snapshot file for file delta.vmdk and hyphened-and-ending-with-delta.vmdk" do
      stub_file1 = double(:ext_name => 'vmdk', :name => 'xxx-delta.vmdk')
      stub_file2 = double(:ext_name => 'vmdk', :name => 'delta.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      expect(result[:snapshot].size).to eq(2)
    end

    it "marks as a snapshot file for file 123456.vmdk and hyphened-and-ending-with-6-digits.vmdk" do
      stub_file1 = double(:ext_name => 'vmdk', :name => '123456.vmdk')
      stub_file2 = double(:ext_name => 'vmdk', :name => 'xxx-123456.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      expect(result[:snapshot].size).to eq(2)
    end

    it "marks as a disk file for file hyphened-but-not-ending-with-delta.vmdk" do
      stub_file1 = double(:ext_name => 'vmdk', :name => 'xx-xxx-notdelta.vmdk')
      stub_file2 = double(:ext_name => 'vmdk', :name => 'anything.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      expect(result[:disk].size).to eq(2)
    end

    it "marks as a disk file for file hyphened-but-not-ending-with-6-digits.vmdk" do
      stub_file1 = double(:ext_name => 'vmdk', :name => 'x-xxx-12345678.vmdk')
      stub_file2 = double(:ext_name => 'vmdk', :name => '1234.vmdk')
      result = described_class.split_file_types([stub_file1, stub_file2])
      expect(result[:disk].size).to eq(2)
    end

    it "marks as a snapshot file for files with extenstion .vmsd and .vmsn" do
      files = []
      %w(vmsd vmsn).each { |f| files << double(:ext_name => f) }
      result = described_class.split_file_types(files)
      expect(result[:snapshot].size).to eq(2)
    end

    it "marks as vm_ram for files with extension .nvram and .vswp" do
      files = []
      %w(nvram vswp).each { |f| files << double(:ext_name => f) }
      result = described_class.split_file_types(files)
      expect(result[:vm_ram].size).to eq(2)
    end

    it "marks as vm_misc for files with extension .vmx, .vmtx, .vmxf, .log and .hlog" do
      files = []
      %w(vmx vmtx vmxf log hlog).each { |f| files << double(:ext_name => f) }
      result = described_class.split_file_types(files)
      expect(result[:vm_misc].size).to eq(5)
    end

    it "marks as snapshot for file with extenstion .redo_whatever_else" do
      file = StorageFile.new(:ext_name => 'redo_file')
      result = described_class.split_file_types([file])
      expect(result[:snapshot].size).to eq(1)
    end

    it "marks as debris for all other file types" do
      file = StorageFile.new(:ext_name => 'whatever_file')
      result = described_class.split_file_types([file])
      expect(result[:debris].size).to eq(1)
    end
  end

  context "#is_file?" do
    it "true when rsc_type == file" do
      file = StorageFile.new(:rsc_type => 'file')
      expect(file.is_file?).to be_truthy
    end

    it "false when rsc_type != dir" do
      file = StorageFile.new(:rsc_type => 'dir')
      expect(file.is_file?).to be_falsey
    end
  end

  context "#is_directory?" do
    it "true when rsc_type == dir" do
      file = StorageFile.new(:rsc_type => 'dir')
      expect(file.is_directory?).to be_truthy
    end

    it "false when rsc_type != dir" do
      file = StorageFile.new(:rsc_type => 'file')
      expect(file.is_directory?).to be_falsey
    end
  end

  context "#v_size_numeric" do
    it "returns the file size" do
      file = StorageFile.new(:size => '500')
      expect(file.v_size_numeric).to eq(500)
    end

    it "0 when empty" do
      file = StorageFile.new
      expect(file.v_size_numeric).to eq(0)
    end
  end

  context "#link_storage_files_to_vms" do
    it "nil when vm_ids_by_path is empty" do
      expect(described_class.link_storage_files_to_vms(StorageFile.new, nil)).to be_falsey
    end

    it "saves to database when update=true" do
      file1 = FactoryBot.create(:storage_file, :name => 'path1/test1.log')
      file2 = FactoryBot.create(:storage_file, :name => 'path2/test2.log', :vm_or_template_id => '1002')
      vm_ids = {
        "path1" => 5001,
        "path2" => 5002
      }
      described_class.link_storage_files_to_vms([file1, file2], vm_ids)
      expect(file1.vm_or_template_id).to eq(5001)
      expect(file2.vm_or_template_id).to eq(5002)
    end

    it "does not save to database when update=false" do
      file1 = FactoryBot.create(:storage_file, :name => 'path1/test1.log')
      vm_ids = {"path1" => 5001}
      described_class.link_storage_files_to_vms(file1, vm_ids, false)
      expect(file1.vm_or_template_id).to eq(5001)

      file1.reload
      expect(file1.vm_or_template_id).to eq(1000)
    end
  end
end
