class MiqUserRole < ApplicationRecord
  SUPER_ADMIN_ROLE_NAME = "EvmRole-super_administrator"
  ADMIN_ROLE_NAME       = "EvmRole-administrator"
  DEFAULT_TENANT_ROLE_NAME = "EvmRole-tenant_administrator"
  include VirtualTotalMixin

  has_many                :entitlements, :dependent => :restrict_with_exception
  has_many                :miq_groups, :through => :entitlements
  has_and_belongs_to_many :miq_product_features, :join_table => :miq_roles_features

  virtual_column :vm_restriction,                   :type => :string

  validates_presence_of   :name
  validates_uniqueness_of :name

  serialize :settings

  default_value_for :read_only, false

  before_destroy { |r| raise _("Read only roles cannot be deleted.") if r.read_only }

  FIXTURE_PATH = File.join(FIXTURE_DIR, table_name)
  FIXTURE_YAML = "#{FIXTURE_PATH}.yml"

  SCOPES = [:base, :sub]

  RESTRICTIONS = {
    :user          => "Only User Owned",
    :user_or_group => "Only User or Group Owned"
  }

  def feature_identifiers
    # TODO: Why can't this be #pluck?
    miq_product_features.collect(&:identifier)
  end

  # @param identifier [String] Product feature identifier to check if this role allows access to it
  #   Returns true when requested feature is directly assigned or a descendant of a feature
  def allows?(identifier:)
    if feature_identifiers.include?(identifier)
      true
    elsif parent = MiqProductFeature.parent_for_feature(identifier)
      allows?(:identifier => parent.identifier)
    else
      false
    end
  end

  # @param identifiers [Array] Product feature identifiers to check if this role allows access
  #   to any of them in the given scope.
  # @param scope [Symbol] Scope to search feature tree for access; must be of type :sub (default), or :base
  #   Returns true if the role gives access to the feature under one of the following scope options:
  #   :sub  - Feature is within the role's feature subtree (this feature and all of its descendants)
  #   :base - Feature is root of the role's feature subtree, i.e. directly assigned to this role
  def allows_any?(identifiers: [], scope: :sub)
    raise _("scope option must be one of #{SCOPES.inspect}") unless SCOPES.include?(scope)
    return false if identifiers.empty?

    role_allows_feature = identifiers.any? { |i| allows?(:identifier => i) }
    if scope == :sub && !role_allows_feature
      child_idents = identifiers.map { |i| MiqProductFeature.feature_children(i) }.flatten
      allows_any?(:identifiers => child_idents, :scope => :sub)
    else
      role_allows_feature
    end
  end

  def self_service?
    [:user_or_group, :user].include?((settings || {}).fetch_path(:restrictions, :vms))
  end

  def limited_self_service?
    (settings || {}).fetch_path(:restrictions, :vms) == :user
  end

  def self.seed
    seed_from_array(YAML.load_file(FIXTURE_YAML))

    Dir.glob(File.join(FIXTURE_PATH, "*.yml")).each do |fixture|
      seed_from_array(YAML.load_file(fixture), true)
    end
  end

  def self.seed_from_array(array, merge_features = false)
    array.each do |hash|
      feature_ids = hash.delete(:miq_product_feature_identifiers)

      hash[:miq_product_features] = MiqProductFeature.where(:identifier => feature_ids).to_a
      role = find_by_name(hash[:name]) || new(hash.except(:id))
      new_role = role.new_record?
      hash[:miq_product_features] &&= role.miq_product_features if !new_role && merge_features
      unless role.settings.nil? # Makse sure existing settings are merged in with the new ones.
        new_settings = hash.delete(:settings) || {}
        role.settings.merge!(new_settings)
      end
      role.update_attributes(hash.except(:id))
    end
  end

  virtual_total :group_count, :miq_groups

  def vm_restriction
    vmr = settings && settings.fetch_path(:restrictions, :vms)
    vmr ? RESTRICTIONS[vmr] : "None"
  end

  def super_admin_user?
    name == SUPER_ADMIN_ROLE_NAME
  end

  def admin_user?
    name == SUPER_ADMIN_ROLE_NAME || name == ADMIN_ROLE_NAME
  end

  def self.default_tenant_role
    find_by(:name => DEFAULT_TENANT_ROLE_NAME)
  end
end
