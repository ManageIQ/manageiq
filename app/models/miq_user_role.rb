class MiqUserRole < ApplicationRecord
  DEFAULT_TENANT_ROLE_NAME = "EvmRole-tenant_administrator"

  has_many                :entitlements, :dependent => :restrict_with_exception
  has_many                :miq_groups, :through => :entitlements
  has_and_belongs_to_many :miq_product_features, :join_table => :miq_roles_features

  virtual_column :vm_restriction,                   :type => :string

  validates :name, :presence => true, :uniqueness_when_changed => {:case_sensitive => false}

  serialize :settings

  default_value_for :read_only, false

  before_destroy do |r|
    if r.read_only
      errors.add(:base, _("Read only roles cannot be deleted."))
      throw :abort
    end
  end

  FIXTURE_PATH = File.join(FIXTURE_DIR, table_name)
  FIXTURE_YAML = "#{FIXTURE_PATH}.yml"

  RESTRICTIONS = {
    :user          => N_('Only User Owned'),
    :user_or_group => N_('Only User or Group Owned')
  }

  def feature_identifiers
    @feature_identifiers ||= miq_product_features.pluck(:identifier)
  end

  # @param identifier [String] Product feature identifier to check if this role allows access to it
  #   Returns true when requested feature is directly assigned or a descendant of a feature
  def allows?(identifier:)
    # all features are children of "everything", so checking it isn't strictly necessary
    # but it simplifies testing
    if feature_identifiers.include?(MiqProductFeature::SUPER_ADMIN_FEATURE) || feature_identifiers.include?(identifier)
      true
    elsif (parent_identifier = MiqProductFeature.feature_parent(identifier))
      allows?(:identifier => parent_identifier)
    else
      false
    end
  end

  # @param identifiers [Array] Product feature identifiers to check if this role allows access
  #   to any of them in the given scope.
  def allows_any?(identifiers: [])
    if identifiers.any? { |i| allows?(:identifier => i) }
      true
    else
      child_idents = identifiers.map { |i| MiqProductFeature.feature_children(i) }.flatten
      if child_idents.present?
        allows_any?(:identifiers => child_idents)
      else
        false
      end
    end
  end

  def self_service?
    [:user_or_group, :user].include?((settings || {}).fetch_path(:restrictions, :vms))
  end

  def limited_self_service?
    (settings || {}).fetch_path(:restrictions, :vms) == :user
  end

  def self.with_roles_excluding(identifier)
    where.not(:id => MiqUserRole.unscope(:select).joins(:miq_product_features)
                                .where(:miq_product_features => {:identifier => identifier})
                                .select(:id))
  end

  def self.seed
    roles = all.index_by(&:name)
    seed_from_array(roles, YAML.load_file(FIXTURE_YAML))

    # NOTE: typically there are no extra fixtures (so merge_features is typically false)
    Dir.glob(File.join(FIXTURE_PATH, "*.yml")).each do |fixture|
      seed_from_array(roles, YAML.load_file(fixture), true)
    end
  end

  def self.seed_from_array(roles, array, merge_features = false)
    features = MiqProductFeature.all
    array.each do |hash|
      feature_ids = hash.delete(:miq_product_feature_identifiers)
      hash[:miq_product_features] = features.select { |f| feature_ids.include?(f.identifier) }
      role = roles[hash[:name]] ||= new(hash.except(:id))
      new_role = role.new_record?
      hash[:miq_product_features] &&= role.miq_product_features if !new_role && merge_features
      unless role.settings.nil? # Make sure existing settings are merged in with the new ones.
        new_settings = hash.delete(:settings) || {}
        role.settings.merge!(new_settings)
      end
      role.attributes = hash.except(:id)
      role.save if role.changed?
    end
  end

  virtual_total :group_count, :miq_groups

  def vm_restriction
    vmr = settings && settings.fetch_path(:restrictions, :vms)
    vmr ? RESTRICTIONS[vmr] : "None"
  end

  def super_admin_user?
    allows?(:identifier => MiqProductFeature::SUPER_ADMIN_FEATURE)
  end

  def tenant_admin_user?
    allows?(:identifier => MiqProductFeature::TENANT_ADMIN_FEATURE)
  end

  def only_my_user_tasks?
    !allows?(:identifier => MiqProductFeature::ALL_TASKS_FEATURE) && allows?(:identifier => MiqProductFeature::MY_TASKS_FEATURE)
  end

  def report_admin_user?
    allows?(:identifier => MiqProductFeature::REPORT_ADMIN_FEATURE)
  end

  def request_admin_user?
    allows?(:identifier => MiqProductFeature::REQUEST_ADMIN_FEATURE)
  end

  def self.default_tenant_role
    find_by(:name => DEFAULT_TENANT_ROLE_NAME)
  end

  def self.display_name(number = 1)
    n_('Role', 'Roles', number)
  end
end
