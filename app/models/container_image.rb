class ContainerImage < ApplicationRecord
  include ComplianceMixin
  include MiqPolicyMixin
  include ScanningMixin

  DOCKER_IMAGE_PREFIX = "docker://"

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

  # Needed for scanning & tagging action
  delegate :my_zone, :to => :ext_management_system

  acts_as_miq_taggable
  virtual_column :display_registry, :type => :string

  after_create :raise_creation_event

  def full_name
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
    if image_ref.start_with?(DOCKER_IMAGE_PREFIX)
      return image_ref[DOCKER_IMAGE_PREFIX.length..-1]
    end
  end

  # The guid is required by the smart analysis infrastructure
  alias_method :guid, :docker_id

  def display_registry
    container_image_registry.present? ? container_image_registry.full_name : _("Unknown image source")
  end

  def scan
    ext_management_system.scan_job_create(self.class.name, id)
  end

  def perform_metadata_scan(ost)
    update!(:last_scan_attempt_on => Time.zone.now.utc)
    miq_cnt_group = ext_management_system.scan_entity_create(ost.scanData)
    # TODO: update smart state infrastructure with a better name
    # than scan_via_miq_vm
    scan_via_miq_vm(miq_cnt_group, ost)
  end

  def tenant_identity
    if ext_management_system
      ext_management_system.tenant_identity
    else
      User.super_admin.tap { |u| u.current_group = Tenant.root_tenant.default_miq_group }
    end
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

  alias_method :perform_metadata_sync, :sync_stashed_metadata
end
