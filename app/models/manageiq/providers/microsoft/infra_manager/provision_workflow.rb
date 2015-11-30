class ManageIQ::Providers::Microsoft::InfraManager::ProvisionWorkflow < ::MiqProvisionInfraWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name')
    super(message, {'platform' => 'microsoft'})
  end

  def allowed_provision_types(_options = {})
    {
      "microsoft" => "Microsoft"
    }
  end

  def self.provider_model
    ManageIQ::Providers::Microsoft::InfraManager
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
    all_clusters     = EmsCluster.where(:ems_id => get_source_and_targets[:ems].try(:id))
    filtered_targets = process_filter(:cluster_filter, EmsCluster, all_clusters)
    allowed_ci(:cluster, [:host], filtered_targets.collect(&:id))
  end
end
