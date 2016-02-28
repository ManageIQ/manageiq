class ContainerImage < ApplicationRecord
  include MiqPolicyMixin
  include ReportableMixin
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
  has_one :openscap_result
  has_many :openscap_rule_results, :through => :openscap_result

  # Needed for scanning
  delegate :my_zone, :to => :ext_management_system

  acts_as_miq_taggable
  virtual_column :display_registry, :type => :string

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
    User.super_admin
  end

  alias_method :perform_metadata_sync, :sync_stashed_metadata
  end
