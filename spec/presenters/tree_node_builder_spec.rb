describe TreeNodeBuilder do
  # Stub .image_path to just return what was sent to it
  before(:each) do
    allow(ActionController::Base.helpers).to receive(:image_path) do |img|
      img
    end
  end

  def compress_id(id)
    ApplicationRecord.compress_id(id)
  end

  context '.build' do
    context 'AvailabilityZone node' do
      %w(amazon azure google openstack openstack_null vmware).each do |az_type|
        it az_type.split("_").map(&:capitalize).join(' ') do
          zone = FactoryGirl.build("availability_zone_#{az_type}")
          node = TreeNodeBuilder.build(zone, nil, {})
          expect(node).to eq(
            :key     => "-#{zone.name}",
            :title   => zone.name,
            :icon    => "100/availability_zone.png",
            :tooltip => "Availability Zone: #{zone.name}",
            :expand  => false
          )
        end
      end
    end

    it 'ConfigurationScript node' do
      config_script = FactoryGirl.build(:ansible_configuration_script)
      node = TreeNodeBuilder.build(config_script, nil, {})
      expect(node).to eq(
        :key     => "-#{config_script.name}",
        :title   => config_script.name,
        :icon    => "100/configuration_script.png",
        :tooltip => "Ansible Tower Job Template: #{config_script.name}",
        :expand  => false
      )
    end

    context 'ExtManagementSystem node' do
      # EmsInfra
      %w(microsoft openstack_infra redhat vmware).each do |provider|
        it "#{provider.gsub('_infra', '').capitalize} EmsInfra" do
          mgmt_system = FactoryGirl.build("ems_#{provider}")
          node = TreeNodeBuilder.build(mgmt_system, nil, {})
          expect(node).to eq(
            :key     => "-#{mgmt_system.name}",
            :title   => mgmt_system.name,
            :icon    => "100/vendor-#{mgmt_system.image_name}.png",
            :tooltip => "Ems Infra: #{mgmt_system.name}",
            :expand  => false
          )
        end
      end

      # EmsCloud
      %w(amazon azure google openstack vmware_cloud).each do |provider|
        it "#{provider.gsub('_cloud', '').capitalize} EmsCloud" do
          mgmt_system = FactoryGirl.build("ems_#{provider}")
          node = TreeNodeBuilder.build(mgmt_system, nil, {})
          expect(node).to eq(
            :key     => "-#{mgmt_system.name}",
            :title   => mgmt_system.name,
            :icon    => "100/vendor-#{mgmt_system.image_name}.png",
            :tooltip => "Ems Cloud: #{mgmt_system.name}",
            :expand  => false
          )
        end
      end

      # All the other ExtManagementSystem classes...
      {
        # :configuration_manager    => "ConfigurationManager",
        # :provisioning_manager     => "ProvisioningManager",
        # :ems_cloud                => "CloudManager",
        # :ems_container            => "ContainerManager",
        # :ems_infra                => "InfraManager",
        # :ems_middleware           => "MiddlewareManager",
        # :ems_network              => "NetworkManager",
        # :ems_storage              => "StorageManager",
        :configuration_manager_ansible_tower => "AnsibleTower ConfigurationManager",
        :configuration_manager_foreman       => "Foreman ConfigurationManager",
        :provisioning_manager_foreman        => "Foreman ProvisioningManager",
        :ems_openshift_enterprise            => "Openshift Enterprise ContainerManager",
        :ems_hawkular                        => "Hawkular MiddlewareManager",
        :ems_azure_network                   => "Azure NetworkManager",
        :ems_amazon_network                  => "Amazon NetworkManager",
        :ems_google_network                  => "Google NetworkManager",
        :ems_nuage_network                   => "Nuage NetworkManager",
        :ems_openstack_network               => "Openstack NetworkManager",
        :ems_vmware_cloud_network            => "Vmware NetworkManager",
        :ems_cinder                          => "CinderManager StorageManager",
        :ems_swift                           => "SwiftManager StorageManager"
      }.each do |factory, ems_name|
        it "#{ems_name} ExtManagementSystem" do
          mgmt_system = FactoryGirl.build(factory)
          node = TreeNodeBuilder.build(mgmt_system, nil, {})
          expect(node).to eq(
            :key     => "-#{mgmt_system.name}",
            :title   => mgmt_system.name,
            :icon    => "100/vendor-#{mgmt_system.image_name}.png",
            :tooltip => "Provider: #{mgmt_system.name}",
            :expand  => false
          )
        end
      end
    end

    it 'ChargebackRate node' do
      rate = FactoryGirl.create(:chargeback_rate)
      node = TreeNodeBuilder.build(rate, nil, {})
      expect(node).to eq(
        :key    => "cr-#{compress_id(rate.id)}",
        :title  => rate.description,
        :icon   => "100/chargeback_rate.png",
        :expand => false
      )
    end

    context "Classification node" do
      it "Regular" do
        classification = FactoryGirl.build(:classification)
        node = TreeNodeBuilder.build(classification, nil, {})
        expect(node).to eq(
          :key          => "-#{classification.name}",
          :title        => classification.description,
          :icon         => "100/folder.png",
          :tooltip      => "Category: #{classification.description}",
          :expand       => false,
          :cfmeNoClick  => true,
          :hideCheckbox => true
        )
      end

      it "Category" do
        category = FactoryGirl.build(:category)
        node = TreeNodeBuilder.build(category, nil, {})
        expect(node).to eq(
          :key          => "-#{category.name}",
          :title        => category.description,
          :icon         => "100/folder.png",
          :tooltip      => "Category: #{category.description}",
          :expand       => false,
          :cfmeNoClick  => true,
          :hideCheckbox => true
        )
      end
    end

    context "Compliance node" do
      it "passed compliance" do
        compliance = FactoryGirl.create(:compliance, :compliant => true)
        node = TreeNodeBuilder.build(compliance, nil, {})
        expect(node).to eq(
          :key    => "cm-#{compress_id(compliance.id)}",
          :title  => "<b>Compliance Check on: </b>#{compliance.timestamp}",
          :icon   => "100/check.png",
          :expand => false
        )
      end

      it "failed compliance" do
        compliance = FactoryGirl.create(:compliance, :compliant => false)
        node = TreeNodeBuilder.build(compliance, nil, {})
        expect(node).to eq(
          :key    => "cm-#{compress_id(compliance.id)}",
          :title  => "<b>Compliance Check on: </b>#{compliance.timestamp}",
          :icon   => "100/x.png",
          :expand => false
        )
      end
    end

    context "ComplianceDetail" do
      it "passed compliance" do
        compliance = FactoryGirl.create(:compliance_detail, :miq_policy_result => true)
        node = TreeNodeBuilder.build(compliance, nil, {})
        expect(node).to eq(
          :key    => "cd-#{compress_id(compliance.id)}",
          :title  => "<b>Policy: </b>#{compliance.miq_policy_desc}",
          :icon   => "100/check.png",
          :expand => false
        )
      end

      it "failed compliance" do
        compliance = FactoryGirl.create(:compliance_detail, :miq_policy_result => false)
        node = TreeNodeBuilder.build(compliance, nil, {})
        expect(node).to eq(
          :key    => "cd-#{compress_id(compliance.id)}",
          :title  => "<b>Policy: </b>#{compliance.miq_policy_desc}",
          :icon   => "100/x.png",
          :expand => false
        )
      end
    end

    it 'Condition node' do
      condition = FactoryGirl.build(:condition)
      node = TreeNodeBuilder.build(condition, nil, {})
      expect(node).to eq(
        :key    => "-#{condition.name}",
        :title  => condition.description,
        :icon   => "100/miq_condition.png",
        :expand => false
      )
    end

    it 'ConfigurationProfile node' do
      config_profile = FactoryGirl.build(:configuration_profile_forman)
      node = TreeNodeBuilder.build(config_profile, nil, {})
      expect(node).to eq(
        :key     => "-#{config_profile.name}",
        :title   => config_profile.name,
        :icon    => "100/configuration_profile.png",
        :tooltip => "Configuration Profile: #{config_profile.name}"
      )
    end

    context "ConfiguredSystem node" do
      it "Base" do
        configured_system = FactoryGirl.build(:configured_system, :hostname => 'foo')
        node = TreeNodeBuilder.build(configured_system, nil, {})
        expect(node).to eq(
          :key     => "-#{configured_system.name}",
          :title   => configured_system.name,
          :icon    => "100/configured_system.png",
          :tooltip => "Configured System: #{configured_system.hostname}",
          :expand  => false
        )
      end

      it "AnsibleTower" do
        configured_system = FactoryGirl.build(:configured_system_foreman, :hostname => 'foreman')
        node = TreeNodeBuilder.build(configured_system, nil, {})
        expect(node).to eq(
          :key     => "-#{configured_system.name}",
          :title   => configured_system.name,
          :icon    => "100/configured_system.png",
          :tooltip => "Configured System: #{configured_system.hostname}",
          :expand  => false
        )
      end

      it "Foreman" do
        configured_system = FactoryGirl.build(:configured_system_foreman, :hostname => 'foreman')
        node = TreeNodeBuilder.build(configured_system, nil, {})
        expect(node).to eq(
          :key     => "-#{configured_system.name}",
          :title   => configured_system.name,
          :icon    => "100/configured_system.png",
          :tooltip => "Configured System: #{configured_system.hostname}",
          :expand  => false
        )
      end
    end

    context "Container node" do
      it "Generic" do
        container = FactoryGirl.build(:container, :name => "bananas")
        node = TreeNodeBuilder.build(container, nil, {})
        expect(node).to eq(
          :key    => "-#{container.name}",
          :title  => container.name,
          :icon   => "100/container.png",
          :expand => false
        )
      end

      it "Kubernetes" do
        container = FactoryGirl.build(:kubernetes_container, :name => "monkeys")
        node = TreeNodeBuilder.build(container, nil, {})
        expect(node).to eq(
          :key    => "-#{container.name}",
          :title  => container.name,
          :icon   => "100/container.png",
          :expand => false
        )
      end
    end

    it 'CustomButton node' do
      button = FactoryGirl.build(:custom_button,
                                 :applies_to_class => 'bleugh',
                                 :applies_to_id    => nil,
                                )
      node = TreeNodeBuilder.build(button, nil, {})
      expect(node).to eq(
        :key     => "-#{button.name}",
        :title   => button.name,
        :icon    => "100/leaf.gif",
        :tooltip => "Button: #{button.description}",
        :expand  => false
      )
    end

    it 'CustomButtonSet node' do
      button_set = FactoryGirl.build(:custom_button_set)
      node = TreeNodeBuilder.build(button_set, nil, {})
      expect(node).to eq(
        :key     => "-#{button_set.name}",
        :title   => button_set.name,
        :icon    => "100/folder.png",
        :tooltip => "Button Group: #{button_set.description}",
        :expand  => false
      )
    end

    context "CustomizationTemplate node" do
      %w(base cloud_init kickstart sysprep).each do |ct|
        it "CustomizationTemplate #{ct.classify}" do
          factory = "customization_template_#{ct}".sub("_base", "")
          template = FactoryGirl.build(factory, :name => ct)
          node = TreeNodeBuilder.build(template, nil, {})
          expect(node).to eq(
            :key    => "-#{template.name}",
            :title  => template.name,
            :icon   => "100/customizationtemplate.png",
            :expand => false
          )
        end
      end
    end

    it 'Dialog node' do
      dialog = FactoryGirl.build(:dialog, :label => 'How much wood would a woodchuck chuck if a woodchuck would chuck wood?')
      node = TreeNodeBuilder.build(dialog, nil, {})
      expect(node).to eq(
        :key    => "-#{dialog.name}",
        :title  => dialog.label,
        :icon   => "100/dialog.png",
        :expand => false
      )
    end

    it 'DialogTab node' do
      tab = FactoryGirl.create(:dialog_tab, :label => '<script>alert("Hacked!");</script>')
      node = TreeNodeBuilder.build(tab, nil, {})
      expect(node).to eq(
        :key    => "-#{compress_id(tab.id)}",
        :title  => ERB::Util.html_escape(tab.label),
        :icon   => "100/dialog_tab.png",
        :expand => false
      )
    end

    it 'DialogGroup node' do
      group = FactoryGirl.create(:dialog_group, :label => '&nbsp;foobar&gt;')
      node = TreeNodeBuilder.build(group, nil, {})
      expect(node).to eq(
        :key    => "-#{compress_id(group.id)}",
        :title  => ERB::Util.html_escape(group.label),
        :icon   => "100/dialog_group.png",
        :expand => false
      )
    end

    it 'DialogField node' do
      field = FactoryGirl.build(:dialog_field, :name => 'random field name', :label => 'foo')
      node = TreeNodeBuilder.build(field, nil, {})
      expect(node).to eq(
        :key    => "-#{field.name}",
        :title  => field.label,
        :icon   => "100/dialog_field.png",
        :expand => false
      )
    end

    context "EmsFolder node" do
      %w(ems_folder storage_cluster inventory_group inventory_root_group).each do |folder_type|
        it folder_type.classify do
          folder = FactoryGirl.build(folder_type)
          node = TreeNodeBuilder.build(folder, nil, {})
          expect(node).to eq(
            :key     => "-#{folder.name}",
            :title   => folder.name,
            :icon    => "100/folder.png",
            :tooltip => "Folder: #{folder.name}",
            :expand  => false
          )
        end
      end

      it "Datacenter" do
        folder = FactoryGirl.build(:datacenter)
        node = TreeNodeBuilder.build(folder, nil, {})
        expect(node).to eq(
          :key     => "-#{folder.name}",
          :title   => folder.name,
          :icon    => "100/datacenter.png",
          :tooltip => "Datacenter: #{folder.name}",
          :expand  => false
        )
      end

      it 'tooltip with %2f' do
        ems_folder = FactoryGirl.create(:ems_folder, :name => 'foo %2f bar')
        node = TreeNodeBuilder.build(ems_folder, nil, {})
        expect(node[:tooltip]).to eq('Folder: foo / bar')
      end
    end

    context "EmsCluster node" do
      %w(ems_cluster ems_cluster_openstack).each do |ems_cluster|
        it ems_cluster.classify do
          cluster = FactoryGirl.create(ems_cluster, :name => "My Cluster")
          node = TreeNodeBuilder.build(cluster, nil, {})
          expect(node).to eq(
            :key     => "c-#{compress_id(MiqRegion.compress_id(cluster.id))}",
            :title   => cluster.name,
            :icon    => "100/cluster.png",
            :tooltip => "Cluster / Deployment Role: #{cluster.name}",
            :expand  => false
          )
        end
      end
    end

    it "GuestDevice node" do
      guest_device = FactoryGirl.create(:guest_device_nic)
      node = TreeNodeBuilder.build(guest_device, nil, {})
      expect(node).to eq(
        :key     => "gd-#{compress_id(guest_device.id)}",
        :title   => guest_device.device_name,
        :icon    => "100/pnic.png",
        :tooltip => "Physical NIC: #{guest_device.device_name}",
        :expand  => false
      )
    end

    context "Host node" do
      %w(host host_microsoft host_redhat host_openstack_infra host_vmware host_vmware_esx).each do |host_factory|
        it host_factory.sub("host_", "").classify do
          host = FactoryGirl.create(host_factory, :name => "My Host")
          node = TreeNodeBuilder.build(host, nil, {})
          expect(node).to eq(
            :key     => "h-#{compress_id(host.id)}",
            :title   => host.name,
            :icon    => "100/host.png",
            :tooltip => "Host / Node: #{host.name}",
            :expand  => false
          )
        end
      end
    end

    it 'IsoDatastore node' do
      mgmt_system = FactoryGirl.build(:ems_redhat)
      datastore = FactoryGirl.build(:iso_datastore, :ext_management_system => mgmt_system)
      node = TreeNodeBuilder.build(datastore, nil, {})
      expect(node).to eq(
        :key    => "-#{datastore.name}",
        :title  => datastore.name,
        :icon   => "100/isodatastore.png",
        :expand => false
      )
    end

    it 'IsoImage node' do
      image = FactoryGirl.create(:iso_image, :name => 'foo')
      node = TreeNodeBuilder.build(image, nil, {})
      expect(node).to eq(
        :key    => "isi-#{compress_id(image.id)}",
        :title  => image.name,
        :icon   => "100/isoimage.png",
        :expand => false
      )
    end

    it 'ResourcePool node' do
      pool = FactoryGirl.build(:resource_pool)
      node = TreeNodeBuilder.build(pool, nil, {})
      expect(node).to eq(
        :key    => "-#{pool.name}",
        :title  => pool.name,
        :icon   => "100/resource_pool.png",
        :expand => false
      )
    end

    it "Lan node" do
      lan = FactoryGirl.build(:lan)
      node = TreeNodeBuilder.build(lan, nil, {})
      expect(node).to eq(
        :key     => "-#{lan.name}",
        :title   => lan.name,
        :icon    => "100/lan.png",
        :tooltip => "Port Group: #{lan.name}",
        :expand  => false
      )
    end

    it "LdapDomain node" do
      domain = FactoryGirl.build(:ldap_domain, :name => "ldap domain")
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node).to eq(
        :key     => "-#{domain.name}",
        :title   => "Domain: #{domain.name}",
        :icon    => "100/ldap_domain.png",
        :tooltip => "LDAP Domain: #{domain.name}",
        :expand  => false
      )
    end

    it "LdapRegion node" do
      region = FactoryGirl.build(:ldap_region)
      node = TreeNodeBuilder.build(region, nil, {})
      expect(node).to eq(
        :key     => "-#{region.name}",
        :title   => "Region: #{region.name}",
        :icon    => "100/ldap_region.png",
        :tooltip => "LDAP Region: #{region.name}",
        :expand  => false
      )
    end

    it 'MiqAeClass node' do
      namespace = FactoryGirl.build(:miq_ae_namespace)
      aclass = FactoryGirl.build(:miq_ae_class, :namespace_id => namespace.id)
      node = TreeNodeBuilder.build(aclass, nil, {})
      expect(node).to eq(
        :key     => "-#{aclass.name}",
        :title   => aclass.name,
        :icon    => "100/ae_class.png",
        :tooltip => "Automate Class: #{aclass.name}",
        :expand  => false
      )
    end

    it 'MiqAeInstance node' do
      instance = FactoryGirl.build(:miq_ae_instance)
      node = TreeNodeBuilder.build(instance, nil, {})
      expect(node).to eq(
        :key     => "-#{instance.name}",
        :title   => instance.name,
        :icon    => "100/ae_instance.png",
        :tooltip => "Automate Instance: #{instance.name}",
        :expand  => false
      )
    end

    it 'MiqAeMethod node' do
      method = FactoryGirl.build(:miq_ae_method)
      node = TreeNodeBuilder.build(method, nil, {})
      expect(node).to eq(
        :key     => "-#{method.name}",
        :title   => method.name,
        :icon    => "100/ae_method.png",
        :tooltip => "Automate Method: #{method.name}",
        :expand  => false
      )
    end

    it 'MiqAeNamespace node' do
      login_as FactoryGirl.create(:user_with_group)

      namespace = FactoryGirl.build(:miq_ae_namespace, :parent_id => 123)
      node = TreeNodeBuilder.build(namespace, nil, {})
      expect(node).to eq(
        :key     => "-#{namespace.name}",
        :title   => namespace.name,
        :icon    => "100/ae_namespace.png",
        :tooltip => "Automate Namespace: #{namespace.name}",
        :expand  => false
      )
    end

    it 'MiqAlertSet node' do
      set = FactoryGirl.build(:miq_alert_set)
      node = TreeNodeBuilder.build(set, nil, {})
      expect(node).to eq(
        :key    => "-#{set.name}",
        :title  => set.name,
        :icon   => "100/miq_alert_profile.png",
        :expand => false
      )
    end

    it 'MiqReport node' do
      report = FactoryGirl.build(:miq_report)
      node = TreeNodeBuilder.build(report, nil, {})
      expect(node).to eq(
        :key    => "-#{report.name}",
        :title  => report.name,
        :icon   => "100/report.png",
        :expand => false
      )
    end

    it 'MiqReportResult node' do
      report_result = FactoryGirl.create(:miq_report_result)
      node = TreeNodeBuilder.build(report_result, nil, {})
      expect(node).to eq(
        :key    => "rr-#{compress_id(report_result.id)}",
        :title  => "",
        :icon   => "100/report_result.png",
        :expand => false
      )
    end

    it 'MiqSchedule node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      allow(MiqServer).to receive(:my_server).and_return(server)
      schedule = FactoryGirl.build(:miq_schedule)
      node = TreeNodeBuilder.build(schedule, nil, {})
      expect(node).to eq(
        :key    => "-#{schedule.name}",
        :title  => schedule.name,
        :icon   => "100/miq_schedule.png",
        :expand => false
      )
    end

    it "MiqScsiLun node" do
      scsi_lun = FactoryGirl.create(:miq_scsi_lun, :canonical_name => 'foo')
      node = TreeNodeBuilder.build(scsi_lun, nil, {})
      expect(node).to eq(
        :key     => "sl-#{compress_id(scsi_lun.id)}",
        :title   => scsi_lun.canonical_name,
        :icon    => "100/lun.png",
        :tooltip => "LUN: #{scsi_lun.canonical_name}",
        :expand  => false
      )
    end

    it "MiqScsiTarget node" do
      scsi_target = FactoryGirl.create(:miq_scsi_target)
      node = TreeNodeBuilder.build(scsi_target, nil, {})
      name = "SCSI Target #{scsi_target.target} (#{scsi_target.iscsi_name})"
      expect(node).to eq(
        :key     => "sg-#{compress_id(scsi_target.id)}",
        :title   => name,
        :icon    => "100/target_scsi.png",
        :tooltip => "Target: #{name}",
        :expand  => false
      )
    end

    it 'MiqServer node' do
      zone   = FactoryGirl.build(:zone)
      server = FactoryGirl.build(:miq_server, :zone => zone)
      node = TreeNodeBuilder.build(server, nil, {})
      expect(node).to eq(
        :key     => "-#{server.name}",
        :title   => "Server: #{server.name} []",
        :icon    => "100/miq_server.png",
        :tooltip => "Server: #{server.name} []",
        :expand  => true
      )
    end

    it 'MiqAlert node' do
      alert = FactoryGirl.build(:miq_alert)
      node = TreeNodeBuilder.build(alert, nil, {})
      expect(node).to eq(
        :key    => "-#{alert.name}",
        :title  => alert.description,
        :icon   => "100/miq_alert.png",
        :expand => false
      )
    end

    it 'MiqAction node' do
      action = FactoryGirl.build(:miq_action, :name => "raise_automation_event")
      node = TreeNodeBuilder.build(action, nil, {:tree => :action_tree})
      expect(node).to eq(
        :key    => "-#{action.name}",
        :title  => action.description,
        :icon   => "100/miq_action_Test.png",
        :expand => false
      )
    end

    it 'MiqEventDefinition node' do
      event = FactoryGirl.build(:miq_event_definition)
      node = TreeNodeBuilder.build(event, nil, {})
      expect(node).to eq(
        :key    => "-#{event.name}",
        :title  => event.description,
        :icon   => "100/event-#{event.name}.png",
        :expand => false
      )
    end

    it 'MiqGroup node' do
      group = FactoryGirl.build(:miq_group)
      node = TreeNodeBuilder.build(group, nil, {})
      expect(node).to eq(
        :key    => "-#{group.name}",
        :title  => group.name,
        :icon   => "100/group.png",
        :expand => false
      )
    end

    it 'MiqPolicy node' do
      policy = FactoryGirl.create(:miq_policy, :towhat => 'Vm', :active => true, :mode => 'control')
      node = TreeNodeBuilder.build(policy, nil, {})
      expect(node).to eq(
        :key    => "p-#{compress_id(policy.id)}",
        :title  => policy.description,
        :icon   => "100/miq_policy_vm.png",
        :expand => false
      )
    end

    it 'MiqPolicySet node' do
      policy_set = FactoryGirl.build(:miq_policy_set, :name => 'Just a set')
      node = TreeNodeBuilder.build(policy_set, nil, {})
      expect(node).to eq(
        :key    => "-#{policy_set.name}",
        :title  => policy_set.description,
        :icon   => "100/policy_profile_inactive.png",
        :expand => false
      )
    end

    it 'MiqUserRole node' do
      role = FactoryGirl.build(:miq_user_role)
      node = TreeNodeBuilder.build(role, nil, {})
      expect(node).to eq(
        :key    => "-#{role.name}",
        :title  => role.name,
        :icon   => "100/miq_user_role.png",
        :expand => false
      )
    end

    it "OrchestrationTemplateCfn node" do
      template = FactoryGirl.build(:orchestration_template_cfn)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).to eq(
        :key    => "-#{template.name}",
        :title  => template.name,
        :icon   => "100/orchestration_template_cfn.png",
        :expand => false
      )
    end

    it "OrchestrationTemplateHot node" do
      template = FactoryGirl.build(:orchestration_template_hot_with_content)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).to eq(
        :key    => "-#{template.name}",
        :title  => template.name,
        :icon   => "100/orchestration_template_hot.png",
        :expand => false
      )
    end

    it "OrchestrationTemplateAzure node" do
      template = FactoryGirl.build(:orchestration_template_azure_with_content)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).to eq(
        :key    => "-#{template.name}",
        :title  => template.name,
        :icon   => "100/orchestration_template_azure.png",
        :expand => false
      )
    end

    it "OrchestrationTemplateVnfd node" do
      template = FactoryGirl.build(:orchestration_template_vnfd_with_content)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).to eq(
        :key    => "-#{template.name}",
        :title  => template.name,
        :icon   => "100/orchestration_template_vnfd.png",
        :expand => false
      )
    end

    it "ManageIQ::Providers::Vmware::CloudManager::OrchestrationTemplate node" do
      template = FactoryGirl.build(:orchestration_template_vmware_cloud)
      node = TreeNodeBuilder.build(template, nil, {})
      expect(node).to eq(
        :key    => "-#{template.name}",
        :title  => template.name,
        :icon   => "100/orchestration_template_vapp.png",
        :expand => false
      )
    end

    context "PxeImage node" do
      %w(pxe_image pxe_image_ipxe pxe_image_pxelinux).each do |factory|
        it factory.classify do
          image = FactoryGirl.build(factory)
          node = TreeNodeBuilder.build(image, nil, {})
          expect(node).to eq(
            :key    => "-#{image.name}",
            :title  => image.name,
            :icon   => "100/pxeimage.png",
            :expand => false
          )
        end
      end
    end

    it "WindowsImage node" do
      image = FactoryGirl.build(:windows_image)
      node = TreeNodeBuilder.build(image, nil, {})
      expect(node).to eq(
        :key    => "-#{image.name}",
        :title  => image.name,
        :icon   => "100/os-windows_generic.png",
        :expand => false
      )
    end

    it "PxeImageType node" do
      image_type = FactoryGirl.create(:pxe_image_type, :name => 'foo')
      node = TreeNodeBuilder.build(image_type, nil, {})
      expect(node).to eq(
        :key    => "pit-#{compress_id(image_type.id)}",
        :title  => image_type.name,
        :icon   => "100/pxeimagetype.png",
        :expand => false
      )
    end

    it "PxeServer node" do
      server = FactoryGirl.build(:pxe_server)
      node = TreeNodeBuilder.build(server, nil, {})
      expect(node).to eq(
        :key    => "-#{server.name}",
        :title  => server.name,
        :icon   => "100/pxeserver.png",
        :expand => false
      )
    end

    context "Service node" do
      %w(
        service_template
        service_template_ansible_tower
        service_template_orchestration
      ).each do |factory|
        it factory.classify do
          service = FactoryGirl.create(:service)
          node = TreeNodeBuilder.build(service, nil, {})
          expect(node).to eq(
            :key    => "s-#{compress_id(service.id)}",
            :title  => service.name,
            :icon   => "100/service.png",
            :expand => false
          )
        end
      end
    end

    it "ServiceResource node" do
      resource = FactoryGirl.create(:service_resource)
      node = TreeNodeBuilder.build(resource, nil, {})
      expect(node).to eq(
        :key    => "sr-#{compress_id(resource.id)}",
        :title  => resource.resource_name,
        :icon   => "100/service_template.png",
        :expand => false
      )
    end

    context "ServiceTemplate node" do
      %w(
        service_template
        service_template_ansible_tower
        service_template_orchestration
      ).each do |factory|
        it factory.classify do
          template = FactoryGirl.build(factory,
                                       :name   => "test template",
                                       :tenant => FactoryGirl.create(:tenant))
          node = TreeNodeBuilder.build(template, nil, {})
          expect(node).to eq(
            :key    => "-#{template.name}",
            :title  => "#{template.name} (#{template.tenant.name})",
            :icon   => "100/service_template.png",
            :expand => false
          )
        end
      end
    end

    it "ServiceTemplateCatalog node" do
      catalog = FactoryGirl.build(:service_template_catalog,
                                  :name   => "test template catalog",
                                  :tenant => FactoryGirl.create(:tenant))
      node = TreeNodeBuilder.build(catalog, nil, {})
      expect(node).to eq(
        :key    => "-#{catalog.name}",
        :title  => "#{catalog.name} (#{catalog.tenant.name})",
        :icon   => "100/service_template_catalog.png",
        :expand => false
      )
    end

    it "Snapshot node" do
      snapshot = FactoryGirl.build(:snapshot, :name => "Polaroid Picture")
      node = TreeNodeBuilder.build(snapshot, nil, {})
      expect(node).to eq(
        :key         => "-#{snapshot.name}",
        :title       => snapshot.name,
        :icon        => "100/snapshot.png",
        :tooltip     => snapshot.name,
        :expand      => false,
        :highlighted => true
      )
    end

    it "Storage node" do
      storage = FactoryGirl.build(:storage)
      node = TreeNodeBuilder.build(storage, nil, {})
      expect(node).to eq(
        :key    => "-#{storage.name}",
        :title  => storage.name,
        :icon   => "100/storage.png",
        :expand => false,
      )
    end

    it "Switch node" do
      switch = FactoryGirl.build(:switch, :name => "Lights")
      node = TreeNodeBuilder.build(switch, nil, {})
      expect(node).to eq(
        :key     => "-#{switch.name}",
        :title   => switch.name,
        :icon    => "100/switch.png",
        :tooltip => "Switch: #{switch.name}",
        :expand  => false
      )
    end

    it "User node" do
      user = FactoryGirl.build(:user)
      node = TreeNodeBuilder.build(user, nil, {})
      expect(node).to eq(
        :key    => "-#{user.name}",
        :title  => user.name,
        :icon   => "100/user.png",
        :expand => false
      )
    end

    it "MiqSearch node" do
      search = FactoryGirl.build(:miq_search)
      node = TreeNodeBuilder.build(search, nil, {})
      expect(node).to eq(
        :key     => "-#{search.name}",
        :title   => search.description,
        :icon    => "100/filter.png",
        :tooltip => "Filter: #{search.description}",
        :expand  => false
      )
    end

    it "MiqDialog node" do
      dialog = FactoryGirl.build(:miq_dialog)
      node = TreeNodeBuilder.build(dialog, nil, {})
      expect(node).to eq(
        :key    => "-#{dialog.name}",
        :title  => dialog.description,
        :icon   => "100/miqdialog.png",
        :expand => false
      )
    end

    it "MiqRegion node" do
      region = FactoryGirl.build(:miq_region, :description => 'Elbonia')
      node = TreeNodeBuilder.build(region, nil, {})
      expect(node).to eq(
        :key    => "-#{region.name}",
        :title  => region.description,
        :icon   => "100/miq_region.png",
        :expand => true
      )
    end

    it "MiqWidget node" do
      widget = FactoryGirl.build(:miq_widget)
      node = TreeNodeBuilder.build(widget, nil, {})
      expect(node).to eq(
        :key     => "-#{widget.name}",
        :title   => widget.title,
        :icon    => "100/#{widget.content_type}_widget.png",
        :tooltip => widget.title,
        :expand  => false
      )
    end

    it "MiqWidgetSet node" do
      widget_set = FactoryGirl.build(:miq_widget_set, :name => 'foo')
      node = TreeNodeBuilder.build(widget_set, nil, {})
      expect(node).to eq(
        :key     => "-#{widget_set.name}",
        :title   => widget_set.name,
        :icon    => "100/dashboard.png",
        :tooltip => widget_set.name,
        :expand  => false
      )
    end

    it "VmdbTableEvm node" do
      table = FactoryGirl.build(:vmdb_table_evm, :name => "a table")
      node = TreeNodeBuilder.build(table, nil, {})
      expect(node).to eq(
        :key    => "-#{table.name}",
        :title  => table.name,
        :icon   => "100/vmdbtableevm.png",
        :expand => false
      )
    end

    it "VmdbIndex node" do
      index = FactoryGirl.create(:vmdb_index, :name => "foo")
      node = TreeNodeBuilder.build(index, nil, {})
      expect(node).to eq(
        :key    => "ti-#{compress_id(index.id)}",
        :title  => index.name,
        :icon   => "100/vmdbindex.png",
        :expand => false
      )
    end

    context "VmOrTemplate node" do
      # Template classes
      {
        :miq_template          => "Base",
        :template_cloud        => "ManageIQ::Providers::CloudManager::Template",
        :template_infra        => "ManageIQ::Providers::InfraManager::Template",
        :template_amazon       => "ManageIQ::Providers::Amazon::CloudManager::Template",
        :template_azure        => "ManageIQ::Providers::Azure::CloudManager::Template",
        :template_google       => "ManageIQ::Providers::Google::CloudManager::Template",
        :template_openstack    => "ManageIQ::Providers::Openstack::CloudManager::Template",
        :template_vmware_cloud => "ManageIQ::Providers::Vmware::CloudManager::Template",
        :template_microsoft    => "ManageIQ::Providers::Microsoft::InfraManager::Template",
        :template_redhat       => "ManageIQ::Providers::Microsoft::InfraManager::Template",
        :template_vmware       => "ManageIQ::Providers::Vmware::InfraManager::Template",
        :template_xen          => "TemplateXen",
      }.each do |factory, vm_type|
        it vm_type do
          template = FactoryGirl.build(factory, :name => "template", :template => true)
          node = TreeNodeBuilder.build(template, nil, {})
          expect(node).to eq(
            :key    => "-#{template.name}",
            :title  => template.name,
            :icon   => "100/currentstate-archived.png",
            :expand => false
          )
        end
      end

      # Vm classes
      {
        :vm              => "Base",
        :vm_cloud        => "ManageIQ::Providers::CloudManager::Vm",
        :vm_infra        => "ManageIQ::Providers::InfraManager::Vm",
        :vm_server       => "VmServer",
        :vm_amazon       => "ManageIQ::Providers::Amazon::CloudManager::Vm",
        :vm_azure        => "ManageIQ::Providers::Azure::CloudManager::Vm",
        :vm_google       => "ManageIQ::Providers::Google::CloudManager::Vm",
        :vm_openstack    => "ManageIQ::Providers::Openstack::CloudManager::Vm",
        :vm_vmware_cloud => "ManageIQ::Providers::Vmware::CloudManager::Vm",
        :vm_microsoft    => "ManageIQ::Providers::Microsoft::InfraManager::Vm",
        :vm_redhat       => "ManageIQ::Providers::Redhat::InfraManager::Vm",
        :vm_vmware       => "ManageIQ::Providers::Vmware::InfraManager::Vm",
        :vm_xen          => "VmXen",
      }.each do |factory, vm_type|
        it vm_type do
          vm = FactoryGirl.build(factory)
          node = TreeNodeBuilder.build(vm, nil, {})
          expect(node).to eq(
            :key     => "-#{vm.name}",
            :title   => vm.name,
            :icon    => "100/currentstate-archived.png",
            :tooltip => "VM: #{vm.name} (Click to view)",
            :expand  => false
          )
        end
      end

      it "Vm node with /" do
        vm = FactoryGirl.create(:vm_amazon, :name => "foo / bar")
        node = TreeNodeBuilder.build(vm, "foo", {})
        expect(node[:title]).to eq("foo / bar")
      end

      it "Vm node with %2f" do
        vm = FactoryGirl.create(:vm_amazon, :name => "foo %2f bar")
        node = TreeNodeBuilder.build(vm, nil, {})
        expect(node[:title]).to eq("foo / bar")
      end

      it "Vm node with tooltip" do
        vm = FactoryGirl.create(:vm_amazon, :name => "name")
        node = TreeNodeBuilder.build(vm, nil, {})
        expect(node[:tooltip]).to eq(_("VM: %{name} (Click to view)") % {:name => vm.name})
      end
    end

    it "Zone node" do
      zone = FactoryGirl.build(:zone, :name => "foo")
      node = TreeNodeBuilder.build(zone, nil, {})
      name = "Zone: #{zone.description}"
      expect(node).to eq(
        :key     => "-#{zone.name}",
        :title   => name,
        :icon    => "100/zone.png",
        :tooltip => name,
        :expand  => false
      )
    end

    it "expand attribute of node should be set to true when open_all is true and expand is nil in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", {:expand => nil, :open_all => true})
      expect(node[:expand]).to eq(true)
    end

    it "expand attribute of node should be set to false when open_all is true and expand is set to false in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", {:expand => false, :open_all => true})
      expect(node[:expand]).to eq(false)
    end

    it "expand attribute of node should be set to true when open_all and expand are true in options" do
      tenant = FactoryGirl.build(:tenant)
      node = TreeNodeBuilder.build(tenant, "root", {:expand => true, :open_all => true})
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

  context "Nodes for Server By Roles/Roles By Servers trees" do
    before(:each) do
      @miq_server = EvmSpecHelper.local_miq_server
      @server_role = FactoryGirl.create(
        :server_role,
        :name              => "smartproxy",
        :description       => "SmartProxy",
        :max_concurrent    => 1,
        :external_failover => false,
        :role_scope        => "zone"
      )

      @priority = AssignedServerRole::DEFAULT_PRIORITY
      @assigned_server_role = FactoryGirl.create(
        :assigned_server_role,
        :miq_server_id  => @miq_server.id,
        :server_role_id => @server_role.id,
        :active         => true,
        :priority       => 1
      )
    end

    it 'Node for ServerRole' do
      node = TreeNodeBuilder.build(@server_role, nil, {})
      expect(node[:key]).to eq("role-#{MiqRegion.compress_id(@server_role.id)}")
      expect(node[:title]).to eq("Role: SmartProxy (stopped)")
    end

    it 'Node for AssignedServerRole' do
      node = TreeNodeBuilder.build(@assigned_server_role, nil, {})
      expect(node[:key]).to eq("asr-#{MiqRegion.compress_id(@assigned_server_role.id)}")
      expect(node[:title]).to eq("<strong>Role: SmartProxy</strong> (primary, active, PID=)")
    end

    it 'Node for MiqServer' do
      node = TreeNodeBuilder.build(@miq_server, nil, {})
      expect(node[:key]).to eq("svr-#{MiqRegion.compress_id(@miq_server.id)}")
      expect(node[:title]).to eq("Server: #{@miq_server.name} [#{@miq_server.id}]")
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
      domain = FactoryGirl.create(:miq_ae_system_domain_enabled, :name => "test1")
      node = TreeNodeBuilder.build(domain, nil, {})
      expect(node[:title]).to eq('test1 (Locked)')
    end

    it "should return node text with Locked & Disabled in the text for Locked & Disabled domain" do
      domain = FactoryGirl.create(:miq_ae_system_domain, :name => "test1")
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
