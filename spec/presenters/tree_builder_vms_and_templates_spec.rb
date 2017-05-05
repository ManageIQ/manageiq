describe TreeBuilderVmsAndTemplates do
  let(:ems) { FactoryGirl.create(:ems_vmware, :zone => FactoryGirl.create(:zone)) }
  let(:folder) { FactoryGirl.create(:ems_folder, :ext_management_system => ems) }
  let(:subfolder1) { FactoryGirl.create(:ems_folder) }

  let(:tree) do
    subfolder2 = FactoryGirl.create(:ems_folder)
    subfolder3 = FactoryGirl.create(:datacenter)

    ems.with_relationship_type("ems_metadata") { ems.add_child(folder) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder1) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder2) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder3) }

    {ems => {folder => {subfolder1 => {}, subfolder2 => {}, subfolder3 => {}}}}
  end

  describe "#sort_tree" do
    it "making sure sort_tree was successful for mixed ems_folder types" do
      builder = TreeBuilderVmsAndTemplates.new(ems)
      expect { builder.send(:sort_tree, tree) }.not_to raise_error
    end
  end

  describe "#tree" do
    it "returns vms with display_vms=true" do
      EvmSpecHelper.local_miq_server
      User.current_user = FactoryGirl.create(:user, :settings => {:display => {:display_vms => true}})
      tree
      vms = FactoryGirl.create_list(:vm_vmware, 2, :ext_management_system => ems)
      subfolder1.with_relationship_type("ems_metadata") { vms.each { |vm| subfolder1.add_child(vm) } }

      tree_v = TreeBuilderVmsAndTemplates.new(ems).tree
      expect(tree_v[:title]).to eq(ems.name)
      expect(tree_v[:children].size).to eq(1)

      folders_v = tree_v[:children].first
      expect(folders_v[:title]).to match folder.name
      expect(folders_v[:children].size).to eq(1)

      subfolders_v = folders_v[:children].detect { |f| f[:title] == subfolder1.name }
      expect(subfolders_v).to be_present
      expect(subfolders_v[:children].size).to eq(2)

      ems_vs = subfolders_v[:children]
      expect(ems_vs.map { |e| e[:title] }).to match_array(vms.map(&:name))
    end

    it "returns no vms with display_vms=false" do
      EvmSpecHelper.local_miq_server
      User.current_user = FactoryGirl.create(:user, :settings => {:display => {:display_vms => false}})
      tree
      vms = FactoryGirl.create_list(:vm_vmware, 2, :ext_management_system => ems)
      subfolder1.with_relationship_type("ems_metadata") { vms.each { |vm| subfolder1.add_child(vm) } }

      tree_v = TreeBuilderVmsAndTemplates.new(ems).tree
      expect(tree_v[:title]).to eq(ems.name)
      expect(tree_v[:children].size).to eq(1)

      folders_v = tree_v[:children].first
      expect(folders_v[:title]).to match folder.name
      expect(folders_v[:children].size).to eq(1) # would be 3 if we did not prune

      subfolders_v = folders_v[:children].detect { |f| f[:title] == subfolder1.name }
      expect(subfolders_v).to be_present
      expect(subfolders_v[:children]).to be_blank # no vms in the tree
    end
  end
end
