class MiqHostProvisionRequest < MiqRequest
  alias_attribute :provision_type,      :request_type
  alias_attribute :miq_host_provisions, :miq_request_tasks

  TASK_DESCRIPTION  = 'Host Provisioning'
  SOURCE_CLASS_NAME = 'Host'
  REQUEST_TYPES     = %w{ host_pxe_install }
  ACTIVE_STATES     = %w{ migrated } + self.base_class::ACTIVE_STATES

  validates_inclusion_of :request_type,   :in => REQUEST_TYPES,                          :message => "should be #{REQUEST_TYPES.join(", ")}"
  validates_inclusion_of :request_state,  :in => %w{ pending finished } + ACTIVE_STATES, :message => "should be pending, #{ACTIVE_STATES.join(", ")} or finished"
  validate               :must_have_user

  default_value_for :provision_type, REQUEST_TYPES.first
  default_value_for :message,        "#{TASK_DESCRIPTION} - Request Created"
  default_value_for(:requester)      { |r| r.get_user }

  virtual_column :provision_type, :type => :string

  def host_name
    if self.options[:src_host_ids].length == 1
      host = Host.find_by_id(self.options[:src_host_ids].first)
      host.nil? ? "" : host.name
    else
      "Multiple Hosts"
    end
  end

  def requested_task_idx
    self.options[:src_host_ids]
  end

  def placement_ems
    ems_id, ems_name = options[:placement_ems_name]
    return nil unless ems_id.kind_of?(Numeric)
    ExtManagementSystem.find_by_id(ems_id)
  end

  def placement_cluster
    ems_cluster_id, ems_cluster_name = options[:placement_cluster_name]
    return nil unless ems_cluster_id.kind_of?(Numeric)
    EmsCluster.find_by_id(ems_cluster_id)
  end

  def placement_folder
    ems_folder_id, ems_folder_name = options[:placement_folder_name]
    return nil unless ems_folder_id.kind_of?(Numeric)
    EmsFolder.find_by_id(ems_folder_id)
  end

  def pxe_server
    pxe_server_id, pxe_server_name = options[:pxe_server_id]
    return nil unless pxe_server_id.kind_of?(Numeric)
    PxeServer.find_by_id(pxe_server_id)
  end

  def pxe_image
    pxe_image_id, pxe_image_name = options[:pxe_image_id]
    return nil unless pxe_image_id.kind_of?(Numeric)
    PxeImage.find_by_id(pxe_image_id)
  end

  def src_hosts
    options[:src_host_ids].collect { |id_str| Host.find_by_id(id_str.to_i) }.compact
  end

  def my_role
    'ems_operations'
  end

  def description
    @description ||= "PXE install on [#{self.host_name}] from image [#{get_option_last(:pxe_image_id)}]"
  end

end
