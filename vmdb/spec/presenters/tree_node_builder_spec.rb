require "spec_helper"

describe TreeNodeBuilderDynatree do
  context '.build' do
    it 'ExtManagementSystem node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      node = TreeNodeBuilderDynatree.build(mgmt_system, nil, {})
      node.should_not be_nil
    end

    it 'AvailabilityZone node' do
      zone = FactoryGirl.build(:availability_zone_amazon)
      node = TreeNodeBuilderDynatree.build(zone, nil, {})
      node.should_not be_nil
    end

    it 'ChargebackRate node' do
      rate = FactoryGirl.create(:chargeback_rate)
      node = TreeNodeBuilderDynatree.build(rate, nil, {})
      node.should_not be_nil
    end

    pending 'Condition node' do
    end

    it 'CustomButton node' do
      button = FactoryGirl.build(:custom_button,
        :applies_to_class => 'bleugh',
        :applies_to_id    => nil,
      )
      node = TreeNodeBuilderDynatree.build(button, nil, {})
      node.should_not be_nil
    end

    it 'CustomButtonSet node' do
      button_set = FactoryGirl.build(:custom_button_set)
      node = TreeNodeBuilderDynatree.build(button_set, nil, {})
      node.should_not be_nil
    end

    it 'CustomizationTemplate node' do
      template = FactoryGirl.build(:customization_template)
      node = TreeNodeBuilderDynatree.build(template, nil, {})
      node.should_not be_nil
    end

    it 'Dialog node' do
      dialog = FactoryGirl.build(:dialog, :label => 'How much wood would a woodchuck chuck if a woodchuck would chuck wood?')
      node = TreeNodeBuilderDynatree.build(dialog, nil, {})
      node.should_not be_nil
    end

    it 'DialogTab node' do
      tab = FactoryGirl.create(:dialog_tab, :label => '<script>alert("Hacked!");</script>')
      node = TreeNodeBuilderDynatree.build(tab, nil, {})
      node.should_not be_nil
    end

    it 'DialogGroup node' do
      group = FactoryGirl.create(:dialog_group, :label => '&nbsp;foobar&gt;')
      node = TreeNodeBuilderDynatree.build(group, nil, {})
      node.should_not be_nil
    end

    it 'DialogField node' do
      field = FactoryGirl.build(:dialog_field, :name => 'random field name')
      node = TreeNodeBuilderDynatree.build(field, nil, {})
      node.should_not be_nil
    end

    it 'EmsFolder node' do
      folder = FactoryGirl.build(:ems_folder)
      node = TreeNodeBuilderDynatree.build(folder, nil, {})
      node.should_not be_nil
    end

    it 'EmsCluster node' do
      cluster = FactoryGirl.build(:ems_cluster)
      node = TreeNodeBuilderDynatree.build(cluster, nil, {})
      node.should_not be_nil
    end

    it 'IsoDatastore node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      datastore = FactoryGirl.build(:iso_datastore, :ext_management_system => mgmt_system )
      node = TreeNodeBuilderDynatree.build(datastore, nil, {})
      node.should_not be_nil
    end

    it 'IsoImage node' do
      image = FactoryGirl.create(:iso_image)
      node = TreeNodeBuilderDynatree.build(image, nil, {})
      node.should_not be_nil
    end

    it 'ResourcePool node' do
      pool = FactoryGirl.build(:resource_pool)
      node = TreeNodeBuilderDynatree.build(pool, nil, {})
      node.should_not be_nil
    end

    it 'Vm node' do
      vm = FactoryGirl.build(:vm_amazon)
      node = TreeNodeBuilderDynatree.build(vm, nil, {})
      node.should_not be_nil
    end

    pending 'LdapDomain node' do
    end

    pending 'LdapRegion node' do
    end

    it 'MiqAeClass node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      aclass = FactoryGirl.build(:miq_ae_class, :namespace_id => namespace.id)
      node = TreeNodeBuilderDynatree.build(aclass, nil, {})
      node.should_not be_nil
    end

    it 'MiqAeInstance node' do
      instance = FactoryGirl.build(:miq_ae_instance)
      node = TreeNodeBuilderDynatree.build(instance, nil, {})
      node.should_not be_nil
    end

    pending 'MiqAeMethod node' do
    end

    it 'MiqAeNamespace node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      node = TreeNodeBuilderDynatree.build(namespace, nil, {})
      node.should_not be_nil
    end

    it 'MiqAlertSet node' do
      set = FactoryGirl.build(:miq_alert_set)
      node = TreeNodeBuilderDynatree.build(set, nil, {})
      node.should_not be_nil
    end

    it 'MiqReport node' do
      report = FactoryGirl.build(:miq_report)
      node = TreeNodeBuilderDynatree.build(report, nil, {})
      node.should_not be_nil
    end

    it 'MiqReportResult node' do
      report_result = FactoryGirl.create(:miq_report_result)
      node = TreeNodeBuilderDynatree.build(report_result, nil, {})
      node.should_not be_nil
      node[:icon].should == "report_result.png"
    end

    it 'MiqSchedule node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      MiqServer.stub(:my_server).and_return(server)
      schedule = FactoryGirl.build(:miq_schedule)
      node = TreeNodeBuilderDynatree.build(schedule, nil, {})
      node.should_not be_nil
    end

    it 'MiqServer node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      node = TreeNodeBuilderDynatree.build(server, nil, {})
      node.should_not be_nil
    end

    it 'MiqTemplate node' do
      template = FactoryGirl.build(:miq_template, :name => "template", :location => "abc/abc.vmtx", :template => true, :vendor => "vmware")
      node = TreeNodeBuilderDynatree.build(template, nil, {})
      node.should_not be_nil
    end

    it 'MiqAlert node' do
      alert = FactoryGirl.build(:miq_alert)
      node = TreeNodeBuilderDynatree.build(alert, nil, {})
      node.should_not be_nil
    end

    it 'MiqAction node' do
      action = FactoryGirl.build(:miq_action, :name => "raise_automation_event")
      node = TreeNodeBuilderDynatree.build(action, nil, { :tree => :action_tree })
      node.should_not be_nil
    end

    it 'MiqEvent node' do
      event = FactoryGirl.build(:miq_event)
      node = TreeNodeBuilderDynatree.build(event, nil, {})
      node.should_not be_nil
    end

    it 'MiqGroup node' do
      group = FactoryGirl.build(:miq_group)
      node = TreeNodeBuilderDynatree.build(group, nil, {})
      node.should_not be_nil
    end

    it 'MiqPolicy node' do
      policy = FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control')
      node = TreeNodeBuilderDynatree.build(policy, nil, {})
      node.should_not be_nil
    end

    it 'MiqPolicySet node' do
      policy_set = FactoryGirl.build(:miq_policy_set, :name => 'Just a set')
      node = TreeNodeBuilderDynatree.build(policy_set, nil, {})
      node.should_not be_nil
    end

    it 'MiqUserRole node' do
      role = FactoryGirl.build(:miq_user_role)
      node = TreeNodeBuilderDynatree.build(role, nil, {})
      node.should_not be_nil
    end
    it 'PxeImage node' do
      image = FactoryGirl.build(:pxe_image)
      node = TreeNodeBuilderDynatree.build(image, nil, {})
      node.should_not be_nil
    end

    it 'WindowsImage node' do
      image = FactoryGirl.build(:windows_image)
      node = TreeNodeBuilderDynatree.build(image, nil, {})
      node.should_not be_nil
    end

    it 'PxeImageType node' do
      image_type = FactoryGirl.create(:pxe_image_type)
      node = TreeNodeBuilderDynatree.build(image_type, nil, {})
      node.should_not be_nil
    end

    it 'PxeServer node' do
      server = FactoryGirl.build(:pxe_server)
      node = TreeNodeBuilderDynatree.build(server, nil, {})
      node.should_not be_nil
    end

    pending 'ScanItemSet node' do
    end

    it 'Service node' do
      service = FactoryGirl.create(:service)
      node = TreeNodeBuilderDynatree.build(service, nil, {})
      node.should_not be_nil
    end

    it 'ServiceResource node' do
      resource = FactoryGirl.create(:service_resource)
      node = TreeNodeBuilderDynatree.build(resource, nil, {})
      node.should_not be_nil
    end

    it 'ServiceTemplate node' do
      template = FactoryGirl.build(:service_template, :name => 'test template')
      node = TreeNodeBuilderDynatree.build(template, nil, {})
      node.should_not be_nil
    end

    it 'ServiceTemplateCatalog node' do
      catalog = FactoryGirl.build(:service_template_catalog)
      node = TreeNodeBuilderDynatree.build(catalog, nil, {})
      node.should_not be_nil
    end

    it 'Storage node' do
      storage = FactoryGirl.build(:storage)
      node = TreeNodeBuilderDynatree.build(storage, nil, {})
      node.should_not be_nil
    end

    it 'User node' do
      user = FactoryGirl.build(:user)
      node = TreeNodeBuilderDynatree.build(user, nil, {})
      node.should_not be_nil
    end

    pending 'MiqSearch node' do
    end

    pending 'MiqDialog node' do
      dialog = FactoryGirl.build(:miq_dialog)
      node = TreeNodeBuilderDynatree.build(dialog, nil, {})
      node.should_not be_nil
    end

    it 'MiqRegion node' do
      region = FactoryGirl.build(:miq_region, :description => 'Elbonia')
      node = TreeNodeBuilderDynatree.build(region, nil, {})
      node.should_not be_nil
    end

    it 'MiqWidget node' do
      widget = FactoryGirl.build(:miq_widget)
      node = TreeNodeBuilderDynatree.build(widget, nil, {})
      node.should_not be_nil
    end

    it 'MiqWidgetSet node' do
      widget_set = FactoryGirl.build(:miq_widget_set)
      node = TreeNodeBuilderDynatree.build(widget_set, nil, {})
      node.should_not be_nil
    end

    it 'VmdbTableEvm node' do
      table = FactoryGirl.build(:vmdb_table_evm, :name => 'a table')
      node = TreeNodeBuilderDynatree.build(table, nil, {})
      node.should_not be_nil
    end

    it 'VmdbIndex node' do
      index = FactoryGirl.create(:vmdb_index)
      node = TreeNodeBuilderDynatree.build(index, nil, {})
      node.should_not be_nil
    end

    it 'Zone node' do
      zone = FactoryGirl.build(:zone)
      node = TreeNodeBuilderDynatree.build(zone, nil, {})
      node.should_not be_nil
    end

    pending 'Hash node' do
    end
  end
end
