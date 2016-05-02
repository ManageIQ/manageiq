module TreeKids
  KIDS_GENERATORS = {
    AvailabilityZone       => [:x_get_tree_az_kids],
    ConfigurationProfile   => [:x_get_tree_cpf_kids],
    Compliance             => [:x_get_compliance_kids],
    ComplianceDetail       => [:x_get_compliance_detail_kids, :parents],
    ManageIQ::Providers::Foreman::ConfigurationManager => [:x_get_tree_cmf_kids],
    ManageIQ::Providers::AnsibleTower::ConfigurationManager => [:x_get_tree_cmat_kids],
    CustomButtonSet        => [:x_get_tree_aset_kids],
    Dialog                 => [:x_get_tree_dialog_kids, :type],
    DialogGroup            => [:x_get_tree_dialog_group_kids, :type],
    DialogTab              => [:x_get_tree_dialog_tab_kids, :type],
    ExtManagementSystem    => [:x_get_tree_ems_kids],
    Datacenter             => [:x_get_tree_datacenter_kids, :type],
    EmsFolder              => [:x_get_tree_folder_kids, :type],
    EmsCluster             => [:x_get_tree_cluster_kids],
    GuestDevice            => [:x_get_tree_guest_device_kids],
    Hash                   => [:x_get_tree_custom_kids, :options],
    Host                   => [:x_get_tree_host_kids],
    IsoDatastore           => [:x_get_tree_iso_datastore_kids],
    LdapRegion             => [:x_get_tree_lr_kids],
    MiqAeClass             => [:x_get_tree_class_kids, :type],
    MiqAeNamespace         => [:x_get_tree_ns_kids, :type],
    MiqGroup               => [:x_get_tree_g_kids],
    MiqRegion              => [:x_get_tree_region_kids],
    MiqReport              => [:x_get_tree_r_kids],
    PxeServer              => [:x_get_tree_pxe_server_kids],
    ResourcePool           => [:x_get_resource_pool_kids],
    Service                => [:x_get_tree_service_kids],
    ServiceTemplateCatalog => [:x_get_tree_stc_kids],
    ServiceTemplate        => [:x_get_tree_st_kids, :type],
    Tenant                 => [:x_get_tree_tenant_kids],
    VmdbTableEvm           => [:x_get_tree_vmdb_table_kids],
    Zone                   => [:x_get_tree_zone_kids],
    MiqPolicySet           => [:x_get_tree_pp_kids],
    MiqAction              => [:x_get_tree_ac_kids],
    MiqAlert               => [:x_get_tree_al_kids],
    MiqAlertSet            => [:x_get_tree_ap_kids],
    Condition              => [:x_get_tree_co_kids],
    MiqEventDefinition     => [:x_get_tree_ev_kids, :parents],
    MiqPolicy              => [:x_get_tree_po_kids],
    MiqScsiLun             => [:x_get_tree_lun_kids],
    MiqScsiTarget          => [:x_get_tree_target_kids],
  }
  # Get objects (or count) to [put into a tree under a parent node.
  # TODO: Perhaps push the object sorting down to SQL, if possible -- no point where there are few items.
  # parent  --- Parent object for which we need child tree nodes returned
  # options --- Options:
  #   :count_only           # Return only the count if true -- remove this
  #   :leaf                 # Model name of leaf nodes, i.e. "Vm"
  #   :open_all             # if true open all node (no autoload)
  #   :load_children
  # parents --- an Array of parent object ids, starting from tree root + 1, ending with parent's parent; only available when full_ids and not lazy
  def x_get_tree_kids(parent, count_only, options, parents)
    generator = KIDS_GENERATORS.detect { |k, v| v if parent.kind_of? k }
    return nil unless generator
    method = generator[1][0]
    attributes = generator[1][1..-1].collect do |attribute_name|
      case attribute_name
      when :options then options
      when :type then options[:type]
      when :parents then parents
      end
    end
    send(method, *([parent, count_only] + attributes))
  end

  def x_get_tree_g_kids(_, _)
    nil # FIXME: temp until I am done
  end
end
