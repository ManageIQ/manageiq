class MiqProductFeature < ApplicationRecord
  SUPER_ADMIN_FEATURE   = "everything".freeze
  REPORT_ADMIN_FEATURE  = "miq_report_superadmin".freeze
  REQUEST_ADMIN_FEATURE = "miq_request_approval".freeze
  MY_TASKS_FEATURE      = "miq_task_my_ui".freeze
  ALL_TASKS_FEATURE     = "miq_task_all_ui".freeze
  TENANT_ADMIN_FEATURE  = "rbac_tenant".freeze

  include_concern "Seeding"

  acts_as_tree

  has_and_belongs_to_many :miq_user_roles, :join_table => :miq_roles_features
  has_many :miq_product_features_shares
  has_many :shares, :through => :miq_product_features_shares
  belongs_to :tenant

  virtual_delegate :identifier, :to => :parent, :prefix => true, :allow_nil => true, :type => :string

  validates :identifier, :uniqueness_when_changed => true, :presence => true

  DETAIL_ATTRS = [
    :name,
    :description,
    :feature_type,
    :hidden,
    :protected,
    :tenant_id
  ]

  FEATURE_TYPE_ORDER = %w(view control admin node).freeze
  REQUIRED_ATTRIBUTES = [:identifier].freeze
  OPTIONAL_ATTRIBUTES = %i(name feature_type description children hidden protected).freeze
  ALLOWED_ATTRIBUTES = (REQUIRED_ATTRIBUTES + OPTIONAL_ATTRIBUTES).freeze
  MY_TENANT_FEATURE_ROOT_IDENTIFIERS = %w(rbac_tenant_manage_quotas).freeze
  TENANT_FEATURE_ROOT_IDENTIFIERS = (%w(dialog_new_editor dialog_edit_editor dialog_copy_editor dialog_delete) + MY_TENANT_FEATURE_ROOT_IDENTIFIERS).freeze

  def name
    value = self[:name]
    self[:tenant_id] ? "#{value} (#{tenant.name})" : value
  end

  def description
    value = self[:description]
    self[:tenant_id] ? "#{value} for tenant #{tenant.name}" : value
  end

  def self.tenant_identifier(identifier, tenant_id)
    "#{identifier}_tenant_#{tenant_id}"
  end

  def self.my_root_tenant_identifier?(identifier)
    MY_TENANT_FEATURE_ROOT_IDENTIFIERS.include?(identifier)
  end

  def self.root_tenant_identifier?(identifier)
    TENANT_FEATURE_ROOT_IDENTIFIERS.include?(identifier)
  end

  def self.current_tenant_identifier(identifier)
    tenant_identifier(identifier, User.current_tenant.id) if identifier && feature_details(identifier) && root_tenant_identifier?(identifier)
  end

  def self.feature_root
    features.keys.detect { |k| feature_parent(k).nil? }
  end

  def self.feature_parent(identifier)
    features[identifier.to_s].try(:[], :parent)
  end

  def self.feature_children(identifier, sort = true)
    feat = features[identifier.to_s]
    if feat && !feat[:details][:hidden] && feat[:children]
      visible_children = feat[:children].select { |f| !feature_hidden(f) }
      sort ? sort_children(visible_children) : visible_children
    else
      []
    end
  end

  # Are we ever going to need to sort these?
  def self.feature_all_children(identifier, sort = true)
    children = feature_children(identifier, false)
    return [] if children.empty?
    result   = children + children.flat_map { |c| feature_all_children(c, false) }
    sort ? sort_children(result) : result
  end

  def self.feature_details(identifier)
    feat = features[identifier.to_s]
    feat[:details] if feat && !feat[:details][:hidden]
  end

  def self.feature_hidden(identifier)
    feat = features[identifier.to_s]
    feat[:details][:hidden] if feat
  end

  def self.feature_exists?(ident)
    features.key?(ident)
  end

  def self.invalidate_caches
    @feature_cache = nil
    @obj_cache = nil
    @detail = nil
  end

  # invalidate feature cache on this server and others
  #
  # called when data in the features change (typically tenant data).
  # This then uses the queue to tell other servers they need to update as well.
  def self.invalidate_caches_queue
    invalidate_caches
    MiqQueue.broadcast(
      :class_name  => name,
      :method_name => "invalidate_caches"
    )
  end

  def self.features
    @feature_cache ||= begin
      # create hash with parent identifier and details
      features = select(:id, :identifier).select(*DETAIL_ATTRS)
                                         .select(:parent_identifier)
                                         .includes(:tenant)
                                         .each_with_object({}) do |f, h|
        parent_ident = f.parent_identifier
        details      = DETAIL_ATTRS.each_with_object({}) { |a, dh| dh[a] = f.send(a) }
        h[f.identifier] = {:parent => parent_ident, :children => [], :details => details}
      end
      # populate the children based upon parent identifier
      features.each do |identifier, n|
        if (parent = n[:parent])
          features[parent][:children] << identifier
        end
      end
      features
    end
  end

  def self.sort_children(children)
    # Sort by feature_type and name forcing the ordering of feature_type to match FEATURE_TYPE_ORDER
    children.sort_by do |c|
      details = feature_details(c)
      [FEATURE_TYPE_ORDER.index(details[:feature_type]), details[:name], c]
    end
  end

  def self.seed
    seed_features
  end

  def self.with_tenant_feature_root_features
    where(:identifier => TENANT_FEATURE_ROOT_IDENTIFIERS)
  end

  def self.seed_single_tenant_miq_product_features(tenant)
    result = MiqProductFeature.with_tenant_feature_root_features.map do |miq_product_feature|
      {
        :name         => miq_product_feature.name,
        :description  => miq_product_feature.description,
        :feature_type => 'admin',
        :hidden       => false,
        :identifier   => tenant_identifier(miq_product_feature.identifier, tenant.id),
        :tenant_id    => tenant.id,
        :parent_id    => miq_product_feature.id
      }
    end

    MiqProductFeature.invalidate_caches
    MiqProductFeature.create(result).map(&:identifier)
  end

  def self.seed_tenant_miq_product_features
    Tenant.in_my_region.all.flat_map { |t| seed_single_tenant_miq_product_features(t) }
  end

  def self.seed_features
    transaction do
      features = all.index_by(&:identifier)

      root_file, other_files = seed_files

      seen = seed_from_hash(YAML.load_file(root_file), seen, nil, features)
      root_feature = find_by(:identifier => SUPER_ADMIN_FEATURE)

      other_files.each do |file|
        seed_from_array(YAML.load_file(file), seen, root_feature)
      end

      tenant_identifiers = seed_tenant_miq_product_features
      deletes = where.not(:identifier => seen.values.flatten + tenant_identifiers).destroy_all
      _log.info("Deleting product features: #{deletes.collect(&:identifier).inspect}") unless deletes.empty?
      seen
    end
  end

  def self.seed_from_array(array, seen = nil, parent = nil, features = nil)
    Array.wrap(array).each do |hash|
      seed_from_hash(hash, seen, parent, features)
    end
  end

  def self.seed_from_hash(hash, seen = nil, parent = nil, features = nil)
    seen ||= Hash.new { |h, k| h[k] = [] }

    children = hash.delete(:children) || []
    hash.delete(:parent_identifier)

    hash[:parent]   = parent
    feature, status = seed_feature(hash, features)
    seen[status] << hash[:identifier]

    children.each do |child|
      seed_from_hash(child, seen, feature, features)
    end
    seen
  end

  def self.seed_feature(hash, features)
    feature = features ? features[hash[:identifier]] : find_by(:identifier => hash[:identifier])

    status = :unchanged
    if feature
      feature.attributes = hash
      if feature.changed?
        _log.info("Updating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
        feature.save
        status = :updated
      end
    else
      _log.info("Creating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
      feature = create(hash.except(:id))
      status = :created
      feature.seed_vm_explorer_for_custom_roles
    end
    return feature, status
  end

  def self.find_all_by_identifier(features)
    where(:identifier => features)
  end

  def self.obj_features
    @obj_cache ||= begin
      # create hash with parent identifier and details
      features = select('*').select(:parent_identifier).each_with_object({}) do |f, h|
        parent_ident = f.parent_identifier
        h[f.identifier] = {:parent => parent_ident, :children => [], :feature => f}
      end

      # populate the children based on parent identifier
      features.each do |_, n|
        if (parent = n[:parent])
          features[parent][:children] << n[:feature]
        end
      end

      features
    end
  end

  def self.obj_feature_all_children(identifier)
    obj_features.fetch_path(identifier.to_s, :children)
  end

  def self.obj_feature_children(identifier)
    obj_feature_all_children(identifier).try(:reject, &:hidden?)
  end

  def self.obj_feature_parent(identifier)
    obj_features.fetch_path(identifier.to_s, :parent)
  end

  def self.obj_feature_ancestors(identifier)
    feature = obj_features[identifier.to_s]
    return [] unless feature

    parent_feature = obj_features[feature[:parent]].try(:[], :feature)
    return [] unless parent_feature

    obj_feature_ancestors(parent_feature.identifier).unshift(parent_feature)
  end

  ### Instance methods

  def seed_vm_explorer_for_custom_roles
    return unless identifier == "vm_explorer"

    MiqUserRole.includes(:miq_product_features).select { |r| r.feature_identifiers.include?("vm") && !r.feature_identifiers.include?("vm_explorer") }.each do |role|
      role.miq_product_features << self
      role.save!
    end
  end

  def details
    @details ||= begin
      attributes.symbolize_keys.slice(*DETAIL_ATTRS).merge(
        :children => children.where(:hidden => [false, nil])
      )
    end
  end

  def self.display_name(number = 1)
    n_('Product Feature', 'Product Features', number)
  end
end
