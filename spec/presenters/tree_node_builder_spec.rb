describe TreeNodeBuilder do
  context '.build' do
    it 'ExtManagementSystem node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      node = TreeNodeBuilder.build(mgmt_system, nil, {})
      expect(node).not_to be_nil
    end

    it 'AvailabilityZone node' do
      zone = FactoryGirl.build(:availability_zone_amazon)
      node = TreeNodeBuilder.build(zone, nil, {})
      expect(node).not_to be_nil
    end

    it 'ChargebackRate node' do
      rate = FactoryGirl.create(:chargeback_rate)
      node = TreeNodeBuilder.build(rate, nil, {})
      expect(node).not_to be_nil
    end

    it 'CustomButton node' do
      button = FactoryGirl.build(:custom_button,
                                 :applies_to_class => 'bleugh',
                                 :applies_to_id    => nil,
                                )
      node = TreeNodeBuilder.build(button, nil, {})
      expect(node).not_to be_nil
    end

    it 'CustomButtonSet node' do
      button_set = FactoryGirl.build(:custom_button_set)
      node = TreeNodeBuilder.build(button_set, nil, {})
      expect(node).not_to be_nil
    end

    it 'CustomizationTemplate node' do
      template = FactoryGirl.build(:customization_template)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).not_to be_nil
    end

    it 'Dialog node' do
      dialog = FactoryGirl.build(:dialog, :label => 'How much wood would a woodchuck chuck if a woodchuck would chuck wood?')
      node = TreeNodeBuilder.build(dialog, nil, {})
      expect(node).not_to be_nil
    end

    it 'DialogTab node' do
      tab = FactoryGirl.create(:dialog_tab, :label => '<script>alert("Hacked!");</script>')
      node = TreeNodeBuilder.build(tab, nil, {})
      expect(node).not_to be_nil
    end

    it 'DialogGroup node' do
      group = FactoryGirl.create(:dialog_group, :label => '&nbsp;foobar&gt;')
      node = TreeNodeBuilder.build(group, nil, {})
      expect(node).not_to be_nil
    end

    it 'DialogField node' do
      field = FactoryGirl.build(:dialog_field, :name => 'random field name', :label => 'foo')
      node = TreeNodeBuilder.build(field, nil, {})
      expect(node).not_to be_nil
    end

    it 'EmsFolder node' do
      folder = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilder.build(folder, nil, {})
      expect(node).not_to be_nil
    end

    it 'valid EmsCluster node' do
      cluster = FactoryGirl.create(:ems_cluster, :name => "My Cluster")
      node = TreeNodeBuilder.build(cluster, nil, {})
      expect(node).not_to be_nil

      expect(node[:key]).to eq("c-#{MiqRegion.compress_id(cluster.id)}")
      expect(node[:title]).to eq(cluster.name)
      expect(node[:icon]).to eq(ActionController::Base.helpers.image_path('100/cluster.png'))
      expect(node[:tooltip]).to eq("Cluster / Deployment Role: #{cluster.name}")
    end

    it 'valid Host Node' do
      host = FactoryGirl.create(:host, :name => "My Host")
      node = TreeNodeBuilder.build(host, nil, {})

      expect(node[:key]).to eq("h-#{MiqRegion.compress_id(host.id)}")
      expect(node[:title]).to eq(host.name)
      expect(node[:icon]).to eq(ActionController::Base.helpers.image_path(('100/host.png')))
      expect(node[:tooltip]).to eq("Host / Node: #{host.name}")
    end

    it 'IsoDatastore node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      datastore = FactoryGirl.build(:iso_datastore, :ext_management_system => mgmt_system)
      node = TreeNodeBuilder.build(datastore, nil, {})
      expect(node).not_to be_nil
    end

    it 'IsoImage node' do
      image = FactoryGirl.create(:iso_image, :name => 'foo')
      node = TreeNodeBuilder.build(image, nil, {})
      expect(node).not_to be_nil
    end

    it 'ResourcePool node' do
      pool = FactoryGirl.build(:resource_pool)
      node = TreeNodeBuilder.build(pool, nil, {})
      expect(node).not_to be_nil
    end

    it 'Vm node' do
      vm = FactoryGirl.build(:vm_amazon)
      node = TreeNodeBuilder.build(vm, nil, {})
      expect(node).not_to be_nil
    end

    it 'Vm node with /' do
      vm = FactoryGirl.create(:vm_amazon, :name => 'foo / bar')
      node = TreeNodeBuilder.build(vm, 'foo', {})
      expect(node[:title]).to eq('foo / bar')
    end

    it 'Vm node with %2f' do
      vm = FactoryGirl.create(:vm_amazon, :name => 'foo %2f bar')
      node = TreeNodeBuilder.build(vm, nil, {})
      expect(node[:title]).to eq('foo / bar')
    end

    it 'EmsFolder tooltip with %2f' do
      ems_folder = FactoryGirl.create(:ems_folder, :name => 'foo %2f bar')
      node = TreeNodeBuilder.build(ems_folder, nil, {})
      expect(node[:tooltip]).to eq('Folder: foo / bar')
    end

    it 'MiqAeClass node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      aclass = FactoryGirl.build(:miq_ae_class, :namespace_id => namespace.id)
      node = TreeNodeBuilder.build(aclass, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqAeInstance node' do
      instance = FactoryGirl.build(:miq_ae_instance)
      node = TreeNodeBuilder.build(instance, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqAeNamespace node' do
      login_as FactoryGirl.create(:user_with_group)

      namespace = FactoryGirl.build(:miq_ae_namespace)
      node = TreeNodeBuilder.build(namespace, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqAlertSet node' do
      set = FactoryGirl.build(:miq_alert_set)
      node = TreeNodeBuilder.build(set, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqReport node' do
      report = FactoryGirl.build(:miq_report)
      node = TreeNodeBuilder.build(report, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqReportResult node' do
      report_result = FactoryGirl.create(:miq_report_result)
      node = TreeNodeBuilder.build(report_result, nil, {})
      expect(node).not_to be_nil
      expect(node[:icon]).to eq(ActionController::Base.helpers.image_path('100/report_result.png'))
    end

    it 'MiqSchedule node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      allow(MiqServer).to receive(:my_server).and_return(server)
      schedule = FactoryGirl.build(:miq_schedule)
      node = TreeNodeBuilder.build(schedule, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqServer node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      node = TreeNodeBuilder.build(server, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqTemplate node' do
      template = FactoryGirl.build(:miq_template, :name => "template", :location => "abc/abc.vmtx", :template => true, :vendor => "vmware")
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqAlert node' do
      alert = FactoryGirl.build(:miq_alert)
      node = TreeNodeBuilder.build(alert, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqAction node' do
      action = FactoryGirl.build(:miq_action, :name => "raise_automation_event")
      node = TreeNodeBuilder.build(action, nil, :tree => :action_tree)
      expect(node).not_to be_nil
    end

    it 'MiqEventDefinition node' do
      event = FactoryGirl.build(:miq_event_definition)
      node = TreeNodeBuilder.build(event, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqGroup node' do
      group = FactoryGirl.build(:miq_group)
      node = TreeNodeBuilder.build(group, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqPolicy node' do
      policy = FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control')
      node = TreeNodeBuilder.build(policy, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqPolicySet node' do
      policy_set = FactoryGirl.build(:miq_policy_set, :name => 'Just a set')
      node = TreeNodeBuilder.build(policy_set, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqUserRole node' do
      role = FactoryGirl.build(:miq_user_role)
      node = TreeNodeBuilder.build(role, nil, {})
      expect(node).not_to be_nil
    end
    it 'PxeImage node' do
      image = FactoryGirl.build(:pxe_image)
      node = TreeNodeBuilder.build(image, nil, {})
      expect(node).not_to be_nil
    end

    it 'WindowsImage node' do
      image = FactoryGirl.build(:windows_image)
      node = TreeNodeBuilder.build(image, nil, {})
      expect(node).not_to be_nil
    end

    it 'PxeImageType node' do
      image_type = FactoryGirl.create(:pxe_image_type, :name => 'foo')
      node = TreeNodeBuilder.build(image_type, nil, {})
      expect(node).not_to be_nil
    end

    it 'PxeServer node' do
      server = FactoryGirl.build(:pxe_server)
      node = TreeNodeBuilder.build(server, nil, {})
      expect(node).not_to be_nil
    end

    it 'Service node' do
      service = FactoryGirl.create(:service)
      node = TreeNodeBuilder.build(service, nil, {})
      expect(node).not_to be_nil
    end

    it 'ServiceResource node' do
      resource = FactoryGirl.create(:service_resource)
      node = TreeNodeBuilder.build(resource, nil, {})
      expect(node).not_to be_nil
    end

    it 'ServiceTemplate node' do
      template = FactoryGirl.build(:service_template, :name => 'test template')
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).not_to be_nil
    end

    it 'ServiceTemplateCatalog node' do
      catalog = FactoryGirl.build(:service_template_catalog)
      node = TreeNodeBuilder.build(catalog, nil, {})
      expect(node).not_to be_nil
    end

    it 'Storage node' do
      storage = FactoryGirl.build(:storage)
      node = TreeNodeBuilder.build(storage, nil, {})
      expect(node).not_to be_nil
    end

    it 'User node' do
      user = FactoryGirl.build(:user)
      node = TreeNodeBuilder.build(user, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqDialog node' do
      dialog = FactoryGirl.build(:miq_dialog)
      node = TreeNodeBuilder.build(dialog, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqRegion node' do
      region = FactoryGirl.build(:miq_region, :description => 'Elbonia')
      node = TreeNodeBuilder.build(region, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqWidget node' do
      widget = FactoryGirl.build(:miq_widget)
      node = TreeNodeBuilder.build(widget, nil, {})
      expect(node).not_to be_nil
    end

    it 'MiqWidgetSet node' do
      widget_set = FactoryGirl.build(:miq_widget_set, :name => 'foo')
      node = TreeNodeBuilder.build(widget_set, nil, {})
      expect(node).not_to be_nil
    end

    it 'VmdbTableEvm node' do
      table = FactoryGirl.build(:vmdb_table_evm, :name => 'a table')
      node = TreeNodeBuilder.build(table, nil, {})
      expect(node).not_to be_nil
    end

    it 'VmdbIndex node' do
      index = FactoryGirl.create(:vmdb_index, :name => 'foo')
      node = TreeNodeBuilder.build(index, nil, {})
      expect(node).not_to be_nil
    end

    it 'Zone node' do
      zone = FactoryGirl.build(:zone, :name => 'foo')
      node = TreeNodeBuilder.build(zone, nil, {})
      expect(node).not_to be_nil
    end

    it "expand attribute of node should be set to true when open_all is true and expand is nil in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", :expand => nil, :open_all => true)
      expect(node[:expand]).to eq(true)
    end

    it "expand attribute of node should be set to nil when open_all is true and expand is set to false in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", :expand => false, :open_all => true)
      expect(node[:expand]).to eq(nil)
    end

    it "expand attribute of node should be set to true when open_all and expand are true in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", :expand => true, :open_all => true)
      expect(node[:expand]).to eq(true)
    end

    it 'can handle an ExtManagementSystem node with no name' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      mgmt_system.name = nil
      mgmt_system.id = 'e-1000'
      node = TreeNodeBuilder.build(mgmt_system, nil, {})
      expect(node).not_to be_nil
    end
  end

  context "#node_with_display_name" do
    before do
      login_as FactoryGirl.create(:user_with_group)
    end
    it "should return node text with Disabled in the text for Disabled domain" do
      domain = FactoryGirl.create(:miq_ae_domain,
                                  :name    => "test1",
                                  :enabled => false)
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node[:title]).to eq('test1 (Disabled)')
    end

    it "should return node text with Locked in the text for Locked domain" do
      domain = FactoryGirl.create(:miq_ae_domain,
                                  :name   => "test1",
                                  :system => true)
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node[:title]).to eq('test1 (Locked)')
    end

    it "should return node text with Locked & Disabled in the text for Locked & Disabled domain" do
      domain = FactoryGirl.create(:miq_ae_domain,
                                  :name    => "test1",
                                  :enabled => false,
                                  :system  => true)
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node[:title]).to eq('test1 (Locked & Disabled)')
    end

    it "should return node text with no suffix when Domain is not Locked or Disabled" do
      domain = FactoryGirl.create(:miq_ae_domain, :name => "test1")
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node[:title]).to eq('test1')
    end
  end
end
