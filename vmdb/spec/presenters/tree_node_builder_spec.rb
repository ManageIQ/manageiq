require "spec_helper"

describe TreeNodeBuilder do
  context '.build' do
    it 'ExtManagementSystem node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      node = TreeNodeBuilder.build(mgmt_system, nil, {})
      node.should_not be_nil
    end

    it 'AvailabilityZone node' do
      zone = FactoryGirl.build(:availability_zone_amazon)
      node = TreeNodeBuilder.build(zone, nil, {})
      node.should_not be_nil
    end

    it 'ChargebackRate node' do
      rate = FactoryGirl.create(:chargeback_rate)
      node = TreeNodeBuilder.build(rate, nil, {})
      node.should_not be_nil
    end

    it 'CustomButton node' do
      button = FactoryGirl.build(:custom_button,
        :applies_to_class => 'bleugh',
        :applies_to_id    => nil,
      )
      node = TreeNodeBuilder.build(button, nil, {})
      node.should_not be_nil
    end

    it 'CustomButtonSet node' do
      button_set = FactoryGirl.build(:custom_button_set)
      node = TreeNodeBuilder.build(button_set, nil, {})
      node.should_not be_nil
    end

    it 'CustomizationTemplate node' do
      template = FactoryGirl.build(:customization_template)
      node = TreeNodeBuilder.build(template, nil, {})
      node.should_not be_nil
    end

    it 'Dialog node' do
      dialog = FactoryGirl.build(:dialog, :label => 'How much wood would a woodchuck chuck if a woodchuck would chuck wood?')
      node = TreeNodeBuilder.build(dialog, nil, {})
      node.should_not be_nil
    end

    it 'DialogTab node' do
      tab = FactoryGirl.create(:dialog_tab, :label => '<script>alert("Hacked!");</script>')
      node = TreeNodeBuilder.build(tab, nil, {})
      node.should_not be_nil
    end

    it 'DialogGroup node' do
      group = FactoryGirl.create(:dialog_group, :label => '&nbsp;foobar&gt;')
      node = TreeNodeBuilder.build(group, nil, {})
      node.should_not be_nil
    end

    it 'DialogField node' do
      field = FactoryGirl.build(:dialog_field, :name => 'random field name')
      node = TreeNodeBuilder.build(field, nil, {})
      node.should_not be_nil
    end

    it 'EmsFolder node' do
      folder = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilder.build(folder, nil, {})
      node.should_not be_nil
    end

    it 'EmsCluster node' do
      cluster = FactoryGirl.build(:ems_cluster)
      node = TreeNodeBuilder.build(cluster, nil, {})
      node.should_not be_nil
    end

    it 'IsoDatastore node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      datastore = FactoryGirl.build(:iso_datastore, :ext_management_system => mgmt_system )
      node = TreeNodeBuilder.build(datastore, nil, {})
      node.should_not be_nil
    end

    it 'IsoImage node' do
      image = FactoryGirl.create(:iso_image)
      node = TreeNodeBuilder.build(image, nil, {})
      node.should_not be_nil
    end

    it 'ResourcePool node' do
      pool = FactoryGirl.build(:resource_pool)
      node = TreeNodeBuilder.build(pool, nil, {})
      node.should_not be_nil
    end

    it 'Vm node' do
      vm = FactoryGirl.build(:vm_amazon)
      node = TreeNodeBuilder.build(vm, nil, {})
      node.should_not be_nil
    end

    it 'MiqAeClass node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      aclass = FactoryGirl.build(:miq_ae_class, :namespace_id => namespace.id)
      node = TreeNodeBuilder.build(aclass, nil, {})
      node.should_not be_nil
    end

    it 'MiqAeInstance node' do
      instance = FactoryGirl.build(:miq_ae_instance)
      node = TreeNodeBuilder.build(instance, nil, {})
      node.should_not be_nil
    end

    it 'MiqAeNamespace node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      node = TreeNodeBuilder.build(namespace, nil, {})
      node.should_not be_nil
    end

    it 'MiqAlertSet node' do
      set = FactoryGirl.build(:miq_alert_set)
      node = TreeNodeBuilder.build(set, nil, {})
      node.should_not be_nil
    end

    it 'MiqReport node' do
      report = FactoryGirl.build(:miq_report)
      node = TreeNodeBuilder.build(report, nil, {})
      node.should_not be_nil
    end

    it 'MiqReportResult node' do
      report_result = FactoryGirl.create(:miq_report_result)
      node = TreeNodeBuilder.build(report_result, nil, {})
      node.should_not be_nil
      node[:icon].should == "report_result.png"
    end

    it 'MiqSchedule node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      MiqServer.stub(:my_server).and_return(server)
      schedule = FactoryGirl.build(:miq_schedule)
      node = TreeNodeBuilder.build(schedule, nil, {})
      node.should_not be_nil
    end

    it 'MiqServer node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      node = TreeNodeBuilder.build(server, nil, {})
      node.should_not be_nil
    end

    it 'MiqTemplate node' do
      template = FactoryGirl.build(:miq_template, :name => "template", :location => "abc/abc.vmtx", :template => true, :vendor => "vmware")
      node = TreeNodeBuilder.build(template, nil, {})
      node.should_not be_nil
    end

    it 'MiqAlert node' do
      alert = FactoryGirl.build(:miq_alert)
      node = TreeNodeBuilder.build(alert, nil, {})
      node.should_not be_nil
    end

    it 'MiqAction node' do
      action = FactoryGirl.build(:miq_action, :name => "raise_automation_event")
      node = TreeNodeBuilder.build(action, nil, :tree => :action_tree)
      node.should_not be_nil
    end

    it 'MiqEvent node' do
      event = FactoryGirl.build(:miq_event)
      node = TreeNodeBuilder.build(event, nil, {})
      node.should_not be_nil
    end

    it 'MiqGroup node' do
      group = FactoryGirl.build(:miq_group)
      node = TreeNodeBuilder.build(group, nil, {})
      node.should_not be_nil
    end

    it 'MiqPolicy node' do
      policy = FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control')
      node = TreeNodeBuilder.build(policy, nil, {})
      node.should_not be_nil
    end

    it 'MiqPolicySet node' do
      policy_set = FactoryGirl.build(:miq_policy_set, :name => 'Just a set')
      node = TreeNodeBuilder.build(policy_set, nil, {})
      node.should_not be_nil
    end

    it 'MiqUserRole node' do
      role = FactoryGirl.build(:miq_user_role)
      node = TreeNodeBuilder.build(role, nil, {})
      node.should_not be_nil
    end
    it 'PxeImage node' do
      image = FactoryGirl.build(:pxe_image)
      node = TreeNodeBuilder.build(image, nil, {})
      node.should_not be_nil
    end

    it 'WindowsImage node' do
      image = FactoryGirl.build(:windows_image)
      node = TreeNodeBuilder.build(image, nil, {})
      node.should_not be_nil
    end

    it 'PxeImageType node' do
      image_type = FactoryGirl.create(:pxe_image_type)
      node = TreeNodeBuilder.build(image_type, nil, {})
      node.should_not be_nil
    end

    it 'PxeServer node' do
      server = FactoryGirl.build(:pxe_server)
      node = TreeNodeBuilder.build(server, nil, {})
      node.should_not be_nil
    end

    it 'Service node' do
      service = FactoryGirl.create(:service)
      node = TreeNodeBuilder.build(service, nil, {})
      node.should_not be_nil
    end

    it 'ServiceResource node' do
      resource = FactoryGirl.create(:service_resource)
      node = TreeNodeBuilder.build(resource, nil, {})
      node.should_not be_nil
    end

    it 'ServiceTemplate node' do
      template = FactoryGirl.build(:service_template, :name => 'test template')
      node = TreeNodeBuilder.build(template, nil, {})
      node.should_not be_nil
    end

    it 'ServiceTemplateCatalog node' do
      catalog = FactoryGirl.build(:service_template_catalog)
      node = TreeNodeBuilder.build(catalog, nil, {})
      node.should_not be_nil
    end

    it 'Storage node' do
      storage = FactoryGirl.build(:storage)
      node = TreeNodeBuilder.build(storage, nil, {})
      node.should_not be_nil
    end

    it 'User node' do
      user = FactoryGirl.build(:user)
      node = TreeNodeBuilder.build(user, nil, {})
      node.should_not be_nil
    end

    pending 'MiqDialog node' do
      dialog = FactoryGirl.build(:miq_dialog)
      node = TreeNodeBuilder.build(dialog, nil, {})
      node.should_not be_nil
    end

    it 'MiqRegion node' do
      region = FactoryGirl.build(:miq_region, :description => 'Elbonia')
      node = TreeNodeBuilder.build(region, nil, {})
      node.should_not be_nil
    end

    it 'MiqWidget node' do
      widget = FactoryGirl.build(:miq_widget)
      node = TreeNodeBuilder.build(widget, nil, {})
      node.should_not be_nil
    end

    it 'MiqWidgetSet node' do
      widget_set = FactoryGirl.build(:miq_widget_set)
      node = TreeNodeBuilder.build(widget_set, nil, {})
      node.should_not be_nil
    end

    it 'VmdbTableEvm node' do
      table = FactoryGirl.build(:vmdb_table_evm, :name => 'a table')
      node = TreeNodeBuilder.build(table, nil, {})
      node.should_not be_nil
    end

    it 'VmdbIndex node' do
      index = FactoryGirl.create(:vmdb_index)
      node = TreeNodeBuilder.build(index, nil, {})
      node.should_not be_nil
    end

    it 'Zone node' do
      zone = FactoryGirl.build(:zone)
      node = TreeNodeBuilder.build(zone, nil, {})
      node.should_not be_nil
    end
  end
end
