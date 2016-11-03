describe ManageIQ::Providers::Redhat::InfraManager::Vm::Reconfigure do
  let(:storage) { FactoryGirl.create(:storage_nfs, :ems_ref => "http://example.com/storages/XYZ") }
  let(:vm) { FactoryGirl.create(:vm_redhat, :storage => storage) }

  it "#reconfigurable?" do
    expect(vm.reconfigurable?).to be_truthy
  end

  it "#max_total_vcpus" do
    expect(vm.max_total_vcpus).to eq(160)
  end

  it "#max_cpu_cores_per_socket" do
    expect(vm.max_cpu_cores_per_socket).to eq(16)
  end

  it "#max_vcpus" do
    expect(vm.max_vcpus).to eq(16)
  end

  it "#max_memory_mb" do
    expect(vm.max_memory_mb).to eq(2.terabyte / 1.megabyte)
  end

  context "#build_config_spec" do
    before do
      @options = {:vm_memory        => '1024',
                  :number_of_cpus   => '8',
                  :cores_per_socket => '2',
                  :disk_add         => [{  "disk_size_in_mb"  => "33",
                                           "persistent"       => true,
                                           "thin_provisioned" => true,
                                           "dependent"        => true,
                                           "bootable"         => false
                                        }],
                  :disk_remove      => [{  "disk_name"      => "2520b46a-799b-472d-89ce-d47f5b65ee5e",
                                           "delete_backing" => false
                                        }]
      }
      @vm = FactoryGirl.create(:vm_redhat, :hardware => FactoryGirl.create(:hardware), :storage => storage)
    end
    subject { @vm.build_config_spec(@options) }

    it "memoryMB" do
      expect(subject["memoryMB"]).to eq(1024)
    end

    it "numCPUs" do
      expect(subject["numCPUs"]).to eq(8)
    end

    it "numCoresPerSocket" do
      expect(subject["numCoresPerSocket"]).to eq(2)
    end

    it "disksAdd" do
      disks = subject["disksAdd"]["disks"]
      expect(disks.size).to eq(1)
      disk_to_add = disks[0]
      expect(disk_to_add["disk_size_in_mb"]).to eq("33")
      expect(disk_to_add["thin_provisioned"]).to eq(true)
      expect(disk_to_add["bootable"]).to eq(false)
      expect(subject["disksAdd"]["ems_storage_uid"]).to eq("XYZ")
    end

    it "disksRemove" do
      expect(subject["disksRemove"].size).to eq(1)
      expect(subject["disksRemove"][0]["disk_name"]).to eq("2520b46a-799b-472d-89ce-d47f5b65ee5e")
      expect(subject["disksRemove"][0]["delete_backing"]).to be_falsey
    end
  end

  context "#disk_format_for" do
    context "when storage type is file system" do
      it "returns 'raw' format for FS storage type" do
        expect(vm.disk_format_for(false)).to eq("raw")
      end

      it "returns 'raw' format for thin provisioned" do
        expect(vm.disk_format_for(true)).to eq("raw")
      end
    end

    context "when storage type is block" do
      let(:storage) { FactoryGirl.create(:storage_block) }

      it "returns 'cow' format for block storage type and thin provisioned" do
        expect(vm.disk_format_for(true)).to eq("cow")
      end

      it "returns 'raw' format for block storage type and thick provisioned" do
        expect(vm.disk_format_for(false)).to eq("raw")
      end
    end

    context "when storage type is not file system and not blcok" do
      let(:storage) { FactoryGirl.create(:storage_unknown) }
      it "returns 'raw' format as default" do
        expect(vm.disk_format_for(false)).to eq("raw")
      end
    end
  end
end
