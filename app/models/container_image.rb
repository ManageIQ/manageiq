class ContainerImage < ApplicationRecord
  acts_as_miq_taggable

  include ComplianceMixin
  include MiqPolicyMixin
  include ScanningMixin
  include TenantIdentityMixin
  include CustomAttributeMixin
  include ArchivedMixin
  include NewWithTypeStiMixin
  include CustomActionsMixin
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
  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_many :docker_labels, -> { where(:section => "docker_labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy
  has_one :last_scan_result, :class_name => "ScanResult", :as => :resource, :dependent => :destroy, :autosave => true

  serialize :exposed_ports, Hash
  serialize :environment_variables, Hash

  virtual_column :display_registry, :type => :string
  virtual_total :total_containers, :containers

  after_create :raise_creation_event

  delegate :my_zone, :to => :ext_management_system, :allow_nil => true

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

  def scan(userid = "system")
    ext_management_system.scan_job_create(self, userid)
  end

  def perform_metadata_scan(ost)
    update!(:last_scan_attempt_on => Time.zone.now.utc)
    miq_cnt_group = ext_management_system.scan_entity_create(ost.scanData)
    # TODO: update smart state infrastructure with a better name
    # than scan_via_miq_vm
    scan_via_miq_vm(miq_cnt_group, ost)
  end

  def self.raise_creation_events(container_image_ids)
    where(:id => container_image_ids).find_each do |record|
      MiqEvent.raise_evm_event(record, 'containerimage_created', {})
    end
  end

  def raise_creation_event
    MiqEvent.raise_evm_event(self, 'containerimage_created', {})
  end

  def has_compliance_policies?
    _, plist = MiqPolicy.get_policies_for_target(self, "compliance", "containerimage_compliance_check")
    !plist.blank?
  end

  def openscap_failed_rules_summary
    openscap_rule_results.where(:result => "fail").group(:severity).count.symbolize_keys
  end

  def disconnect_inv
    return if archived?
    _log.info("Disconnecting Image [#{name}] id [#{id}] from EMS [#{ext_management_system.name}] id [#{ext_management_system.id}]")
    self.container_image_registry = nil
    self.deleted_on = Time.now.utc
    save
  end

  def self.disconnect_inv(ids)
    _log.info "Disconnecting Images [#{ids}]"
    where(:id => ids).update_all(:container_image_registry_id => nil, :deleted_on => Time.now.utc)
  end

  alias_method :perform_metadata_sync, :sync_stashed_metadata
end
