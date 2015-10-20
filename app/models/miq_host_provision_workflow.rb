class MiqHostProvisionWorkflow < MiqRequestWorkflow
  def self.base_model
    MiqHostProvisionWorkflow
  end

  def self.automate_dialog_request
    'UI_HOST_PROVISION_INFO'
  end

  def self.default_dialog_file
    'miq_host_provision_dialogs'
  end

  def self.encrypted_options_fields
    [:root_password]
  end

  def supports_iso?
    false
  end

  def create_request(values, requester_id, auto_approve = false)
    super(values, requester_id, auto_approve) { update_selected_storage_names(values) }
  end

  def update_request(request, values, requester_id)
    super(request, values, requester_id) { update_selected_storage_names(values) }
  end

  def get_source_and_targets(_refresh = false)
  end

  def update_field_visibility
    # Determine the visibility of fields based on current values and collect the fields
    # together so we can update the dialog in one pass

    # Show/Hide Fields
    f = Hash.new { |h, k| h[k] = [] }

    show_flag = get_value(@values[:addr_mode]) == 'static' ? :edit : :hide
    f[show_flag] += [:hostname, :ip_addr, :subnet_mask, :gateway]

    # Update field :display value
    f.each { |k, v| show_fields(k, v) }
  end

  def set_default_values
    super
    @values[:attached_ds] = [] if @values[:attached_ds].nil?
    get_source_and_targets
  end

  #
  # Methods for populating lists of allowed values for a field
  # => Input  - A hash containing options specific to the called method
  # => Output - A hash with the format: <value> => <value display name>
  # => New methods can be added as as needed
  #

  def allowed_hosts(_options = {})
    return @allowed_hosts_cache unless @allowed_hosts_cache.nil?

    rails_logger('allowed_hosts', 0)

    host_ids = @values[:src_host_ids]
    hosts = Host.find_all_by_id(host_ids)

    @allowed_hosts_cache  = hosts.collect do |h|
      build_ci_hash_struct(h, [:name, :guid, :uid_ems, :ipmi_address, :mac_address])
    end
    @allowed_hosts_cache
  end

  def allowed_ems(_options = {})
    result = {}

    ManageIQ::Providers::Vmware::InfraManager.select("id, name").each do |e|
      result[e.id] = e.name
    end
    result
  end

  def allowed_clusters(_options = {})
    ems = ExtManagementSystem.find_by_id(get_value(@values[:placement_ems_name]))
    result = {}
    return result if ems.nil?
    ems.ems_clusters.each { |c| result[c.id] = "#{c.v_parent_datacenter} / #{c.name}" }
    result
  end

  def allowed_storages(_options = {})
    result = []
    ems = ExtManagementSystem.find_by_id(get_value(@values[:placement_ems_name]))
    return result if ems.nil?
    ems.storages.each do |s|
      next unless s.store_type == "NFS"
      result << build_ci_hash_struct(s, [:name, :free_space, :total_space])
    end
    result
  end

  # This is for summary screen display purposes only
  def update_selected_storage_names(values)
    values[:attached_ds_names] = Storage.where(:id => values[:attached_ds]).pluck(:name)
  end
end # class MiqHostProvisionWorkflow
