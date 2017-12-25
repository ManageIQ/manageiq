describe Metric::ContainerStorage do
  context ".fill_allocated_container_storage" do
    let(:project1) { FactoryGirl.create(:container_project, :name => 'project1') }
    let(:project2) { FactoryGirl.create(:container_project, :name => 'project2') }
    let(:project3) { FactoryGirl.create(:container_project, :name => 'project3') }

    let(:pvc1) { FactoryGirl.create(:persistent_volume_claim, :capacity => {:storage => 10.gigabytes}) }
    let(:pvc2) { FactoryGirl.create(:persistent_volume_claim, :capacity => {:storage => 1.gigabytes}) }
    let(:pvc3) { FactoryGirl.create(:persistent_volume_claim, :capacity => {:storage => 3.gigabytes}) }

    it "calculates container storage out of persistent volume claims" do
      # single pvc
      project1.persistent_volume_claims << pvc1
      derived_columns = described_class.fill_allocated_container_storage(project1)
      expect(derived_columns[:derived_vm_allocated_disk_storage]).to eq(pvc1.capacity[:storage])

      # multiple pvc's
      project2.persistent_volume_claims << [pvc2, pvc3]
      derived_columns = described_class.fill_allocated_container_storage(project2)
      expect(derived_columns[:derived_vm_allocated_disk_storage]).to eq(pvc2.capacity[:storage] + pvc3.capacity[:storage])
    end

    it "calculates container storage when having zero persistent volume claims" do
      derived_columns = described_class.fill_allocated_container_storage(project3)
      expect(derived_columns[:derived_vm_allocated_disk_storage]).to eq(0)
    end
  end
end
