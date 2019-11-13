describe EmsRefresh::LinkInventory do
  context ".link_ems_inventory", :with_local_miq_server do
    let!(:ems) do
      FactoryBot.create(:ems_vmware, :zone => @zone).tap do |e|
        build_vmware_folder_structure!(e)
        folder = e.ems_folders.find_by(:name => "blue1")
        folder.add_child(FactoryBot.create(:vm_vmware, :name => "vm1", :ems_id => e.id))
        folder.add_child(FactoryBot.create(:vm_vmware, :name => "vm2", :ems_id => e.id))
      end
    end
    let(:folder1)     { ems.ems_folders.find_by(:name => "blue1") }
    let(:folder2)     { ems.ems_folders.find_by(:name => "blue2") }
    let(:vm1)         { ems.vms_and_templates.find_by(:name => "vm1") }
    let(:vm2)         { ems.vms_and_templates.find_by(:name => "vm2") }

    context "when a vm moves to a different folder" do
      before do
        prev_relats = EmsRefresh.vmdb_relats(target)
        new_relats = prev_relats.deep_dup

        new_relats[:folders_to_vms][folder1.id].delete(vm1.id)
        new_relats[:folders_to_vms].delete(folder1.id) if new_relats[:folders_to_vms][folder1.id].empty?
        new_relats[:folders_to_vms][folder2.id] = [vm1.id]

        EmsRefresh.link_ems_inventory(ems, target, prev_relats, new_relats, true)
      end

      context "full refresh" do
        let(:target) { ems }

        it "changes the parent folder and children" do
          expect(vm1.reload.parent_blue_folder).to eq(folder2)
          expect(folder1.children).not_to include(vm1)
          expect(folder2.children).to include(vm1)
        end

        it "doesn't impact other inventory" do
          expect(vm2.reload.parent_blue_folder).to eq(folder1)
          expect(folder1.children).to include(vm2)
        end
      end

      context "targeted refresh" do
        let(:target) { vm1 }

        it "changes the parent folder and children" do
          expect(vm1.reload.parent_blue_folder).to eq(folder2)
          expect(folder1.children).not_to include(vm1)
          expect(folder2.children).to include(vm1)
        end

        it "doesn't impact other inventory" do
          expect(vm2.reload.parent_blue_folder).to eq(folder1)
          expect(folder1.children).to include(vm2)
        end
      end
    end
  end
end
