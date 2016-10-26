describe Menu::DefaultMenu do
  include Spec::Support::MenuHelper

  context 'default_menu' do
    it "does not call gettext translations" do
      expect(Menu::DefaultMenu).not_to receive(:ui_lookup).with(any_args)
      expect(Menu::DefaultMenu).not_to receive(:_)
      expect(Menu::DefaultMenu).not_to receive(:n_)
      Menu::DefaultMenu.default_menu
    end

    it "calls gettext marker" do
      expect(Menu::DefaultMenu).to receive(:N_).at_least(:once).and_call_original
      Menu::DefaultMenu.default_menu
    end
  end

  context "infrastructure_menu_section" do
    before do
      @ems_openstack = FactoryGirl.create(:ems_openstack_infra)
      @ems_vmware = FactoryGirl.create(:ems_vmware)
    end

    it "shows correct title for Hosts submenu item when openstack only records exist" do
      FactoryGirl.create(:host_openstack_infra, :ems_id => @ems_openstack.id)
      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Clusters", "Nodes", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end

    it "shows correct title for Hosts submenu item when non-openstack only records exist" do
      FactoryGirl.create(:host_vmware, :ems_id => @ems_vmware.id)
      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Clusters", "Hosts", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end

    it "shows correct title for Hosts submenu item when both openstack & non-openstack only records exist" do
      FactoryGirl.create(:host_openstack_infra, :ems_id => @ems_openstack.id)
      FactoryGirl.create(:host_vmware, :ems_id => @ems_vmware.id)

      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Clusters", "Hosts / Nodes", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end

    it "shows correct title for Clusters submenu item when openstack only records exist" do
      FactoryGirl.create(:ems_cluster_openstack, :ems_id => @ems_openstack.id)

      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Deployment Roles", "Hosts", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end

    it "shows correct title for Clusters submenu item when non-openstack only records exist" do
      FactoryGirl.create(:ems_cluster_openstack, :ems_id => @ems_vmware.id)

      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Clusters", "Hosts", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end

    it "shows correct title for Clusters submenu item when both openstack & non-openstack only records exist" do
      FactoryGirl.create(:ems_cluster_openstack, :ems_id => @ems_openstack.id)
      FactoryGirl.create(:ems_cluster_openstack, :ems_id => @ems_vmware.id)

      menu = Menu::DefaultMenu.infrastructure_menu_section.items.map(&:name)
      result = ["Providers", "Clusters / Deployment Roles", "Hosts", "Virtual Machines", "Resource Pools",
                "Datastores", "PXE", "Networking", "Requests", "Topology"]
      expect(menu).to eq(result)
    end
  end

  describe "#storage_menu_section" do
    let(:menu) { Menu::DefaultMenu }

    context "when the configuration storage product setting is set to true" do
      it "contains the generic objects item" do
        stub_settings(:product => {:storage => true})
        expect(menu.storage_menu_section.items.map(&:name)).to include(
          "Storage Providers",
          "Volumes",
          "Object Stores",
          "NetApp"
        )
      end
    end

    context "when the configuration storage product setting is not true" do
      it "does not contain the NetApp item" do
        stub_settings(:product => {:storage => "juliet" })
        expect(menu.storage_menu_section.items.map(&:name)).to include(
          "Storage Providers",
          "Volumes",
          "Object Stores",
        )
      end
    end
  end

  describe "#automate_menu_section" do
    let(:menu) { Menu::DefaultMenu }

    context "when the configuration generic object product setting is set to true" do
      it "contains the generic objects item" do
        stub_settings(:product => {:generic_object => true})
        expect(menu.automate_menu_section.items.map(&:name)).to include(
          "Explorer",
          "Simulation",
          "Customization",
          "Generic Objects",
          "Import / Export",
          "Log",
          "Requests"
        )
      end
    end

    context "when the configuration generic object product setting is not true" do
      it "does not contain the generic objects item" do
        stub_settings(:product => {:generic_object => "potato"})
        expect(menu.automate_menu_section.items.map(&:name)).to include(
          "Explorer",
          "Simulation",
          "Customization",
          "Import / Export",
          "Log",
          "Requests"
        )
      end
    end
  end
end
