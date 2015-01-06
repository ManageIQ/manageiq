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

  def allowed_vlans(options = {})
    if @allowed_vlan_cache.nil?
      @vlan_options ||= options
      vlans = {}
      src = get_source_and_targets
      return vlans if src.blank?

      unless @vlan_options[:vlans] == false
        rails_logger('allowed_vlans', 0)
        hosts = get_selected_hosts(src)
        hosts.each { |h| h.switches.each { |s| vlans[s.name] = s.name } }
        rails_logger('allowed_vlans', 1)
      end

      @allowed_vlan_cache = vlans
    end
    filter_by_tags(@allowed_vlan_cache, options)
  end

  def allowed_datacenters(_options = {})
    allowed_ci(:datacenter, [:cluster, :host, :folder])
  end
end
