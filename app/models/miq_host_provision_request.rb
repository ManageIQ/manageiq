class MiqHostProvisionRequest < MiqRequest
  alias_attribute :provision_type,      :request_type
  alias_attribute :miq_host_provisions, :miq_request_tasks

  TASK_DESCRIPTION  = 'Host Provisioning'
  SOURCE_CLASS_NAME = 'Host'
  ACTIVE_STATES     = %w( migrated ) + base_class::ACTIVE_STATES

  validates_inclusion_of :request_state,  :in => %w( pending finished ) + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  virtual_column :provision_type, :type => :string

  def host_name
    if options[:src_host_ids].length == 1
      host = Host.find_by(:id => options[:src_host_ids].first)
      host.nil? ? "" : host.name
    else
      "Multiple Hosts"
    end
  end

  def requested_task_idx
    options[:src_host_ids]
  end

  def placement_ems
    ems_id, _ems_name = options[:placement_ems_name]
    ExtManagementSystem.find_by(:id => ems_id) if ems_id.kind_of?(Numeric)
  end

  def placement_cluster
    ems_cluster_id, _ems_cluster_name = options[:placement_cluster_name]
    EmsCluster.find_by(:id => ems_cluster_id) if ems_cluster_id.kind_of?(Numeric)
  end

  def placement_folder
    ems_folder_id, _ems_folder_name = options[:placement_folder_name]
    EmsFolder.find_by(:id => ems_folder_id) if ems_folder_id.kind_of?(Numeric)
  end

  def pxe_server
    pxe_server_id, _pxe_server_name = options[:pxe_server_id]
    PxeServer.find_by(:id => pxe_server_id) if pxe_server_id.kind_of?(Numeric)
  end

  def pxe_image
    pxe_image_id, _pxe_image_name = options[:pxe_image_id]
    PxeImage.find_by(:id => pxe_image_id) if pxe_image_id.kind_of?(Numeric)
  end

  def src_hosts
    options[:src_host_ids].collect { |id_str| Host.find_by(:id => id_str.to_i) }.compact
  end

  def my_role
    'ems_operations'
  end

  def originating_controller
    "host"
  end

  def event_name(mode)
    "host_provision_request_#{mode}"
  end

  private

  def default_description
    "PXE install on [#{host_name}] from image [#{get_option_last(:pxe_image_id)}]"
  end
end
