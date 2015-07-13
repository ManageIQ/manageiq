class MiqProvisionMicrosoftWorkflow < MiqProvisionInfraWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'microsoft'})
  end

  def allowed_provision_types(_options = {})
    {
      "microsoft" => "Microsoft"
    }
  end

  def self.allowed_templates_vendor
    'microsoft'
  end

  def update_field_visibility(_options = {})
    super

    if get_value(@values[:vm_dynamic_memory])
      display_flag = :edit
    else
      display_flag = :hide
    end
    show_fields(display_flag, [:vm_minimum_memory, :vm_maximum_memory])
  end

  def allowed_datacenters(_options = {})
    allowed_ci(:datacenter, [:cluster, :host, :folder])
  end

  def allowed_clusters(_options = {})
    filtered_targets = process_filter_all(:cluster_filter, EmsCluster)
    filtered_ids = filtered_targets.collect(&:id)
    allowed_ci(:cluster, [:host], filtered_ids)
  end
end
