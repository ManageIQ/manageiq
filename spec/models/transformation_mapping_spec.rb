describe TransformationMapping do
  let(:src) { FactoryGirl.create(:ems_cluster) }
  let(:dst) { FactoryGirl.create(:ems_cluster) }
  let(:vm)  { FactoryGirl.create(:vm_vmware, :ems_cluster => src) }

  let(:mapping) do
    FactoryGirl.create(
      :transformation_mapping,
      :transformation_mapping_items => [TransformationMappingItem.new(:source => src, :destination => dst)]
    )
  end

  describe '#destination' do
    it "finds the destination" do
      expect(mapping.destination(src)).to eq(dst)
    end

    it "returns nil for unmapped source" do
      expect(mapping.destination(FactoryGirl.create(:ems_cluster))).to be_nil
    end
  end

  describe '#valid_cluster?' do
    it 'returns ture if cluster is listed' do
      expect(mapping.valid_cluster?(vm)).to be true
    end

    it 'returns false if cluster is not listed' do
      vm2 = FactoryGirl.create(:vm_vmware, :ems_cluster => FactoryGirl.create(:ems_cluster))
      expect(mapping.valid_cluster?(vm2)).to be false
    end
  end

  describe '#validate_storages' do
    let(:storage1) { FactoryGirl.create(:storage) }
    before do
      mapping.transformation_mapping_items << TransformationMappingItem.new(:source => storage1, :destination => storage1)
      vm.storages << storage1
    end

    it 'returns an empty array if all storages are listed' do
      expect(mapping.validate_storages(vm)).to be_blank
    end

    it 'returns an array of invalid storages' do
      storage2 = FactoryGirl.create(:storage)
      vm.storages << storage2
      expect(mapping.validate_storages(vm)).to eq([storage2])
    end
  end

  describe '#validate_lans' do
    let(:lan1) { FactoryGirl.create(:lan) }
    let(:nic1) { FactoryGirl.create(:guest_device_nic, :lan => lan1) }

    before do
      mapping.transformation_mapping_items << TransformationMappingItem.new(:source => lan1, :destination => lan1)
      vm.hardware = FactoryGirl.create(:hardware, :guest_devices => [nic1])
    end

    it 'returns an empty array if all lans are listed' do
      expect(mapping.validate_lans(vm)).to be_blank
    end

    it 'returns an array of invalid lans' do
      lan2 = FactoryGirl.create(:lan)
      nic2 = FactoryGirl.create(:guest_device_nic, :lan => lan2)
      vm.hardware.guest_devices << nic2
      expect(mapping.validate_lans(vm)).to eq([lan2])
    end
  end
end
