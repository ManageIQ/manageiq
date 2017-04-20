class ContainerImage < ApplicationRecord
  include ComplianceMixin
  include MiqPolicyMixin
  include ScanningMixin
  include TenantIdentityMixin
  include CustomAttributeMixin
  include ArchivedMixin
  include_concern 'Purging'

  DOCKER_IMAGE_PREFIX = "docker://"
  DOCKER_PULLABLE_PREFIX = "docker-pullable://".freeze
  DOCKER_PREFIXES = [DOCKER_IMAGE_PREFIX, DOCKER_PULLABLE_PREFIX].freeze

  belongs_to :container_image_registry
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :containers
  has_many :container_nodes, -> { distinct }, :through => :containers
  has_many :container_groups, -> { distinct }, :through => :containers
  has_many :container_projects, -> { distinct }, :through => :container_groups
  has_many :guest_applications, :dependent => :destroy
  has_one :computer_system, :as => :managed_entity, :dependent => :destroy
  has_one :operating_system, :through => :computer_system
  has_one :openscap_result, :dependent => :destroy
  has_many :openscap_rule_results, :through => :openscap_result
  has_many :labels, -> { where(:section => "labels") }, :class_name => CustomAttribute, :as => :resource, :dependent => :destroy
  has_many :docker_labels, -> { where(:section => "docker_labels") }, :class_name => CustomAttribute, :as => :resource, :dependent => :destroy

  serialize :exposed_ports, Hash
  serialize :environment_variables, Hash

  acts_as_miq_taggable
  virtual_column :display_registry, :type => :string

  after_create :raise_creation_event

  def full_name
    return docker_id if image_ref && image_ref.start_with?(DOCKER_PULLABLE_PREFIX)
    result = ""
    result << "#{container_image_registry.full_name}/" unless container_image_registry.nil?
    result << name
    result << ":#{tag}" unless tag.nil?
    result << "@#{digest}" unless digest.nil?
    result
  end

  def operating_system=(value)
    create_computer_system if computer_system.nil?
    computer_system.operating_system = value
  end

  def docker_id
    DOCKER_PREFIXES.each do |prefix|
      return image_ref[prefix.length..-1] if image_ref.start_with?(prefix)
    end
    nil
  end

  # The guid is required by the smart analysis infrastructure
  alias_method :guid, :docker_id

  def display_registry
    container_image_registry.present? ? container_image_registry.full_name : _("Unknown image source")
  end

  def scan
    ext_management_system.scan_job_create(self)
  end

  def perform_metadata_scan(ost)
    update!(:last_scan_attempt_on => Time.zone.now.utc)
    miq_cnt_group = ext_management_system.scan_entity_create(ost.scanData)
    # TODO: update smart state infrastructure with a better name
    # than scan_via_miq_vm
    scan_via_miq_vm(miq_cnt_group, ost)
  end

  def raise_creation_event
    MiqEvent.raise_evm_event(self, 'containerimage_created', {})
  end

  def has_compliance_policies?
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "containerimage_compliance_check")
    !plist.blank?
  end

  def annotate_deny_execution(causing_policy)
    # TODO: support sti and replace check with inplementing only for OpenShift providers
    unless ext_management_system.kind_of?(ManageIQ::Providers::Openshift::ContainerManagerMixin)
      _log.error("#{__method__} only applicable for OpenShift Providers")
      return
    end
    ext_management_system.annotate(
      "image",
      digest,
      "security.manageiq.org/failed-policy" => causing_policy,
      "images.openshift.io/deny-execution"  => "true"
    )
  end

  def openscap_failed_rules_summary
    openscap_rule_results.where(:result => "fail").group(:severity).count.symbolize_keys
  end

  def disconnect_inv
    return if ems_id.nil?
    _log.info "Disconnecting Image [#{name}] id [#{id}] from EMS [#{ext_management_system.name}]" \
    "id [#{ext_management_system.id}] "
    self.container_image_registry = nil
    self.old_ems_id = ems_id
    self.ext_management_system = nil
    self.deleted_on = Time.now.utc
    save
  end

  alias_method :perform_metadata_sync, :sync_stashed_metadata

  def refresh_openshift_information
    return if digest.blank?
    openshift_image = ext_management_system.connect.get_image(digest)
  rescue KubeException => e
    raise unless e.message.include?("not found")
  else
    openshift_image_data = ManageIQ::Providers::Openshift::ContainerManager::RefreshParser.parse_openshift_image_data(openshift_image)
    EmsRefresh.save_labels_inventory(self,
                                     openshift_image_data.delete(:labels))
    EmsRefresh.save_docker_labels_inventory(self,
                                            openshift_image_data.delete(:docker_labels))
    update(openshift_image_data)
    update(:last_openshift_refresh => Time.now.utc)
  end

  def update_attributes_from_list(attributes, ca_attribute)
    ca_attribute.delete_all
    attributes.each do |ca|
      ca_attribute.create(ca)
    end
  end

  def self.post_refresh_ems(ems_id, update_start_time)
    return if Settings.ems_refresh.openshift.get_container_images # The images are already updated

    update_start_time = update_start_time.utc
    ems = ExtManagementSystem.find(ems_id)

    openshift_data_refresh_delay = Settings.ems_refresh.openshift.container_image_refresh_delay
    refresh_expiry = openshift_data_refresh_delay.days.ago.utc if openshift_data_refresh_delay
    if refresh_expiry
      ems.container_images.where("created_on >= ? OR last_openshift_refresh <= ?",
                                 update_start_time, refresh_expiry)
    else
      ems.container_images.where("created_on >= ?", update_start_time)
    end.each do |image|
      MiqQueue.put(
        :class_name  => image.class.name,
        :instance_id => image.id,
        :method_name => 'refresh_openshift_information'
      )
    end
  end
end
