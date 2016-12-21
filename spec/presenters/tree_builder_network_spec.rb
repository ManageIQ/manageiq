describe TreeBuilderNetwork do
  context 'TreeBuilderNetwork' do
    before do
      role = MiqUserRole.find_by_name("EvmRole-operator")
      @group = FactoryGirl.create(:miq_group, :miq_user_role => role, :description => "Network Group")
      login_as FactoryGirl.create(:user, :userid => 'network_wilma', :miq_groups => [@group])
      vm = FactoryGirl.create(:vm)
      hardware = FactoryGirl.create(:hardware, :vm_or_template => vm)
      guest_device_with_vm = FactoryGirl.create(:guest_device, :hardware => hardware)
      guest_device = FactoryGirl.create(:guest_device)
      lan = FactoryGirl.create(:lan, :guest_devices => [guest_device_with_vm])
      switch = FactoryGirl.create(:switch, :guest_devices => [guest_device], :lans => [lan])
      network = FactoryGirl.create(:host, :switches => [switch])
      @network_tree = TreeBuilderNetwork.new(:network_tree, :network, {}, true, network)
    end
    it 'returns Host as root' do
      root = @network_tree.send(:root_options)
      expect(root[0]).to eq(@network_tree.instance_variable_get(:@root).name)
      expect(root[1]).to eq(_("Host: %{name}") % {:name => @network_tree.instance_variable_get(:@root).name})
      expect(root[2]).to eq('100/host.png')
    end
    it 'returns Switch as root child' do
      kid = @network_tree.send(:x_get_tree_roots, false)
      expect(kid.first).to be_a_kind_of(Switch)
    end
    it 'returns GuestDevice and Lan as Switch children' do
      parent = @network_tree.send(:x_get_tree_roots, false).first
      kids = @network_tree.send(:x_get_tree_switch_kids, parent, false)
      expect(kids[0]).to be_a_kind_of(GuestDevice)
      expect(kids[1]).to be_a_kind_of(Lan)
    end
    it 'returns Vm as Lan child' do
      parent = @network_tree.send(:x_get_tree_roots, false).first.lans.first
      kid = @network_tree.send(:x_get_tree_lan_kids, parent, false)
      expect(kid.first).to be_a_kind_of(Vm)
    end
    it 'returns nothing as GuestDevice child' do
      parent = @network_tree.send(:x_get_tree_roots, false).first.guest_devices.first
      number_of_kids = @network_tree.send(:x_get_tree_objects, parent, {}, true, nil)
      expect(number_of_kids).to eq(0)
    end
  end
end
