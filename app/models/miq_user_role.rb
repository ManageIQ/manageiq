class MiqUserRole < ActiveRecord::Base
  has_many                :miq_groups, :dependent => :restrict_with_exception
  has_and_belongs_to_many :miq_product_features, :join_table => :miq_roles_features

  virtual_column :group_count,                      :type => :integer
  virtual_column :vm_restriction,                   :type => :string

  validates_presence_of   :name
  validates_uniqueness_of :name

  serialize :settings

  default_value_for :read_only, false

  before_destroy { |r| raise "Read only roles cannot be deleted." if r.read_only }

  include ReportableMixin

  FIXTURE_DIR  = File.join(Rails.root, "db/fixtures")
  FIXTURE_PATH = File.join(FIXTURE_DIR, self.table_name)
  FIXTURE_YAML = "#{FIXTURE_PATH}.yml"

  SCOPES = [:base, :one, :sub ]

  RESTRICTIONS = {
    :user          => "Only User Owned",
    :user_or_group => "Only User or Group Owned"
  }

  def feature_identifiers
    self.miq_product_features.collect(&:identifier)
  end

  def allows?(options={})
    ident = options[:identifier]
    raise "No value provided for option :identifier" if ident.nil?

    if ident.kind_of?(MiqProductFeature)
      feat = ident
      ident = feat.identifier
    end

    return true if self.feature_identifiers.include?(ident)

    return false unless MiqProductFeature.feature_exists?(ident)

    parent = MiqProductFeature.feature_parent(ident)
    return false if parent.nil?

    return self.allows?(:identifier => parent)
  end

  def self.allows?(role, options={})
    role = self.get_role(role)
    return false if role.nil?
    role.allows?(options)
  end

  def allows_any?(options={})
    scope = options[:scope] || :sub
    raise ":scope must be one of #{SCOPES.inspect}" unless SCOPES.include?(scope)

    idents = options[:identifiers].to_miq_a
    return false if idents.empty?

    if [:base, :sub].include?(scope)
      # Check passed in identifiers
      return true if idents.any? {|i| self.allows?(:identifier => i)}
    end

    return false if scope == :base

    # Check children of passed in identifiers (scopes :one and :base)
    return idents.any? {|i| self.allows_any_children?(:scope => (scope == :one ? :base : :sub), :identifier => i)}
  end

  def self.allows_any?(role, options={})
    role = self.get_role(role)
    return false if role.nil?
    role.allows_any?(options)
  end

  def allows_all?(options={})
    scope = options[:scope] || :sub
    raise ":scope must be one of #{SCOPES.inspect}" unless SCOPES.include?(scope)

    options[:scope] ||= :sub
    idents = options[:identifiers].to_miq_a
    return false if idents.empty?

    if [:base, :sub].include?(scope)
      # Check passed in identifiers
      return true if idents.all? {|i| self.allows?(:identifier => i)}
    end
    return false if scope == :base

    # Check children of passed in identifiers (scopes :one and :base)
    return idents.all? {|i| self.allows_all_children?(:scope => (scope == :one ? :base : :sub), :identifier => i)}
  end

  def self.allows_all?(role, options={})
    role = self.get_role(role)
    return false if role.nil?
    role.allows_all?(options)
  end

  def allows_any_children?(options={})
    ident = options.delete(:identifier)
    return false if ident.nil? || !MiqProductFeature.feature_exists?(ident)

    child_idents = MiqProductFeature.feature_children(ident)
    self.allows_any?(options.merge(:identifiers => child_idents))
  end

  def self.allows_any_children?(role, options={})
    role = self.get_role(role)
    return false if role.nil?
    role.allows_any_children?(options)
  end

  def allows_all_children?(options={})
    ident = options.delete(:identifier)
    return false if ident.nil? || !MiqProductFeature.feature_exists?(ident)

    child_idents = MiqProductFeature.feature_children(ident)
    self.allows_all?(options.merge(:identifiers => child_idents))
  end

  def self.allows_all_children?(role, options={})
    role = self.get_role(role)
    return false if role.nil?
    role.allows_all_children?(options)
  end

  def self.get_role(role)
    case role
    when self, nil
      role
    when Integer
      includes(:miq_product_features).find_by_id(role)
    else
      includes(:miq_product_features).find_by_name(role)
    end
  end

  def self_service_role?
    [:user_or_group, :user].include?((self.settings || {}).fetch_path(:restrictions, :vms))
  end

  def limited_self_service_role?
    (self.settings || {}).fetch_path(:restrictions, :vms) == :user
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.seed_from_array(YAML.load_file(FIXTURE_YAML))

      Dir.glob(File.join(FIXTURE_PATH, "*.yml")).each do |fixture|
        self.seed_from_array(YAML.load_file(fixture), true)
      end
    end
  end

  def self.seed_from_array(array, merge_features = false)
    array.each do |hash|
      feature_ids = hash.delete(:miq_product_feature_identifiers)

      hash[:miq_product_features] = MiqProductFeature.where(:identifier => feature_ids).to_a
      role = self.find_by_name(hash[:name]) || self.new(hash.except(:id))
      new_role = role.new_record?
      hash[:miq_product_features] &&= role.miq_product_features if !new_role && merge_features
      unless role.settings.nil? # Makse sure existing settings are merged in with the new ones.
        new_settings = hash.delete(:settings) || {}
        role.settings.merge!(new_settings)
      end
      role.update_attributes(hash.except(:id))
    end
  end

  def group_count
    self.miq_groups.count
  end

  def vm_restriction
    vmr = self.settings && self.settings.fetch_path(:restrictions, :vms)
    return vmr ? RESTRICTIONS[vmr] : "None"
  end
end
