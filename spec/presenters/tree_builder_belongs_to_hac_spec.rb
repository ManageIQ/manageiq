describe TreeBuilderBelongsToHac do
  before do
    login_as FactoryGirl.create(:user_with_group, :role => "operator", :settings => {})
    FactoryGirl.create(:ems_redhat)
    FactoryGirl.create(:ems_google_network)
  end

  let(:edit) { nil }
  let(:group) { FactoryGirl.create(:miq_group) }
  let(:datacenter1) do
    datacenter = FactoryGirl.create(:datacenter)
    datacenter.with_relationship_type("ems_metadata") { datacenter.add_folder(subfolder) }
    datacenter
  end
  let(:datacenter2) { FactoryGirl.create(:datacenter) }
  let(:rp1) do
    rp1 = FactoryGirl.create(:resource_pool, :is_default => true)
    rp1.with_relationship_type("ems_metadata") { rp1.add_child(rp2) }
    rp1
  end
  let(:rp2) { FactoryGirl.create(:resource_pool) }
  let(:cluster) do
    cluster = FactoryGirl.create(:ems_cluster)
    allow(cluster).to receive(:resource_pools) { [rp1] }
    allow(cluster).to receive(:hosts) { [host] }
    cluster
  end
  let(:ems_folder) { FactoryGirl.create(:ems_folder) }
  let(:subfolder) do
    subfolder = FactoryGirl.create(:ems_folder, :name => 'host')
    subfolder.with_relationship_type("ems_metadata") { subfolder.add_child(datacenter2) }
    subfolder.with_relationship_type("ems_metadata") { subfolder.add_child(ems_folder) }
    subfolder.with_relationship_type("ems_metadata") { subfolder.add_host(host) }
    subfolder.with_relationship_type("ems_metadata") { subfolder.add_cluster(cluster) }
    subfolder
  end
  let(:subfolder_vm) do
    subfolder_vm = FactoryGirl.create(:ems_folder, :name => 'vm')
    subfolder_vm.with_relationship_type("ems_metadata") { subfolder_vm.add_child(ems_folder) }
    subfolder_vm
  end
  let(:folder) do
    folder = FactoryGirl.create(:ems_folder)
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(datacenter1) }
    folder
  end
  let(:host) do
    FactoryGirl.create(:host, :ems_cluster => cluster)
  end
  let(:ems_azure_network) do
    network = FactoryGirl.create(:ems_azure_network)
    network.with_relationship_type("ems_metadata") { network.add_child(folder) }
    network
  end

  subject do
    described_class.new(:hac,
                        :hac_tree,
                        {:trees => {}},
                        true,
                        :edit     => edit,
                        :filters  => {},
                        :group    => group,
                        :selected => {})
  end

  describe '#tree_init_options' do
    it 'sets init options correctly' do
      expect(subject.send(:tree_init_options, :hac)).to eq(:full_ids             => true,
                                                           :add_root             => false,
                                                           :lazy                 => false,
                                                           :checkable_checkboxes => edit.present?,
                                                           :selected             => {})
    end
  end

  describe '#set_locals_for_render' do
    it 'sets locals correctly' do
      expect(subject.send(:set_locals_for_render)).to include(:onclick           => false,
                                                              :tree_state        => true,
                                                              :checkboxes        => true,
                                                              :id_prefix         => "hac_",
                                                              :check_url         => "/ops/rbac_group_field_changed/#{group.id || "new"}___",
                                                              :oncheck           => nil,
                                                              :highlight_changes => true)
    end
  end

  describe '#root_options' do
    it 'sets root to empty one' do
      expect(subject.send(:root_options)).to eq([])
    end
  end

  describe '#x_get_tree_roots' do
    it 'returns all ExtManagementSystems' do
      expect(subject.send(:x_get_tree_roots, false, nil)).to eq(ExtManagementSystem.all)
    end
  end

  describe '#x_get_tree_provider_kids' do
    it 'returns datacenter or folder' do
      kids = subject.send(:x_get_kids_provider, ems_azure_network, false)
      expect(kids).to include(datacenter1)
      expect(kids).to include(subfolder)
      expect(kids.length).to eq(2)
    end
  end

  describe '#x_get_tree_folder_kids' do
    it 'returns datacenters, folders, clusters or hosts' do
      kids = subject.send(:x_get_tree_folder_kids, subfolder, false)
      expect(kids).to include(datacenter2)
      expect(kids).to include(ems_folder)
      expect(kids).to include(cluster)
      expect(kids).to include(host)
      expect(kids.length).to eq(4)
    end
  end

  describe '#x_get_tree_datacenter_kids' do
    it 'returns hosts, clusters or folders' do
      kids = subject.send(:x_get_tree_datacenter_kids, datacenter1, false, nil)
      expect(kids).to include(host)
      expect(kids).to include(cluster)
      expect(kids).to include(ems_folder)
      expect(kids.length).to eq(3)
    end
  end

  describe '#x_get_tree_cluster_kids' do
    it 'returns hosts or resource pools' do
      kids = subject.send(:x_get_tree_cluster_kids, cluster, false)
      expect(kids).to include(host)
      expect(kids).to include(rp1)
      expect(kids.length).to eq(2)
    end
  end

  describe '#x_get_resource_pool_kids' do
    it 'returns resource pools' do
      kids = subject.send(:x_get_resource_pool_kids, rp1, false)
      no_kids = subject.send(:x_get_resource_pool_kids, rp2, false)
      expect(kids).to include(rp2)
      expect(no_kids).to eq([])
    end
  end
end
