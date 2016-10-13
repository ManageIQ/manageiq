describe TreeBuilderArchived do
  context 'TreeBuilderArchived' do
    before do
      extend TreeBuilderArchived
      allow(self).to receive(:count_only_or_objects_filtered) do |count_only, objects, name|
        count_only ? objects.size : objects.sort_by{ |object| object[name.to_sym] }
      end
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Archived Group")
      login_as FactoryGirl.create(:user, :userid => 'archived__wilma', :miq_groups => [@group], :settings => {})

      @vm_orph = FactoryGirl.create(:vm_orphaned)
      @template_orph = FactoryGirl.create(:template_orphaned)
      @vm_arch = FactoryGirl.create(:vm)
      @template_arch = FactoryGirl.create(:vm_or_template)

      @vm_arch_cloud = FactoryGirl.create(:vm_cloud)
      @template_arch_cloud = FactoryGirl.create(:template_cloud)
      @vm_orph_cloud = FactoryGirl.create(:vm_cloud_orphaned)
      @template_orph_cloud = FactoryGirl.create(:template_cloud_orphaned)

      allow(ManageIQ::Providers::InfraManager::VmOrTemplate).to receive(:all_orphaned) {[@vm_orph, @template_orph]}
      allow(ManageIQ::Providers::InfraManager::VmOrTemplate).to receive(:all_archived) {[@vm_arch, @template_arch]}
    end
    it '#x_get_tree_arch_orph_nodes' do
      nodes = x_get_tree_arch_orph_nodes('VMs/Templates')
      expect(nodes).to eq([{:id    => "arch",
                            :text  => "<Archived>",
                            :image => "currentstate-archived",
                            :tip   => "Archived VMs/Templates"},
                           {:id    => "orph",
                            :text  => "<Orphaned>",
                            :image => "currentstate-orphaned",
                            :tip   => "Orphaned VMs/Templates"}])
    end
    it '#x_get_tree_custom_kids with hidden Infra VMs returns empty Array' do
      User.current_user.settings[:display] = {:display_vms => false}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::InfraManager::VmOrTemplate'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::InfraManager::VmOrTemplate'})
      expect(nodes_orph).to eq([])
      expect(nodes_arch).to eq([])
    end
    it '#x_get_tree_custom_kids with Infra VMs returns VMs' do
      User.current_user.settings[:display] = {:display_vms => true}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::InfraManager::VmOrTemplate'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::InfraManager::VmOrTemplate'})
      expect(nodes_orph).to eq([@vm_orph, @template_orph])
      expect(nodes_arch).to eq([@vm_arch, @template_arch])
    end
    it '#x_get_tree_custom_kids with hidden Cloud VMs returns empty Array' do
      User.current_user.settings[:display] = {:display_vms => false}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'VmCloud'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'VmCloud'})
      expect(nodes_orph).to eq([])
      expect(nodes_arch).to eq([])
    end
    it '#x_get_tree_custom_kids with Cloud VMs returns VMs' do
      User.current_user.settings[:display] = {:display_vms => true}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'VmCloud'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'VmCloud'})
      expect(nodes_orph).to eq([@vm_orph_cloud])
      expect(nodes_arch).to eq([@vm_arch_cloud])
    end
    it '#x_get_tree_custom_kids with hidden Cloud Templates returns empty Array' do
      User.current_user.settings[:display] = {:display_vms => false}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::CloudManager::Template'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::InfraManager::Template'})
      expect(nodes_orph).to eq([])
      expect(nodes_arch).to eq([])
    end
    it '#x_get_tree_custom_kids with Cloud Templates returns Templates' do
      User.current_user.settings[:display] = {:display_vms => true}
      nodes_orph = x_get_tree_custom_kids({:id => 'orph'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::CloudManager::Template'})
      nodes_arch = x_get_tree_custom_kids({:id => 'arch'},
                                          false,
                                          {:leaf => 'ManageIQ::Providers::CloudManager::Template'})
      expect(nodes_orph).to eq([@template_orph_cloud])
      expect(nodes_arch).to eq([@template_arch_cloud])
    end
  end
end
