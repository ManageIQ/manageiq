class MiqProductFeature < ApplicationRecord
  acts_as_tree

  has_and_belongs_to_many :miq_user_roles, :join_table => :miq_roles_features

  validates_presence_of   :identifier
  validates_uniqueness_of :identifier

  FIXTURE_PATH = Rails.root.join(*["db", "fixtures", table_name])

  DETAIL_ATTRS = [
    :name,
    :description,
    :feature_type,
    :hidden,
    :protected
  ]

  FEATURE_TYPE_ORDER = ["view", "control", "admin", "node"]
  REQUIRED_ATTRIBUTES = [:identifier].freeze
  OPTIONAL_ATTRIBUTES = [:name, :feature_type, :description, :children, :hidden, :protected].freeze
  ALLOWED_ATTRIBUTES = (REQUIRED_ATTRIBUTES + OPTIONAL_ATTRIBUTES).freeze

  def self.feature_yaml(path = FIXTURE_PATH)
    "#{path}.yml".freeze
  end

  def self.feature_root
    features.keys.detect { |k| feature_parent(k).nil? }
  end

  def self.feature_parent(identifier)
    features[identifier.to_s].try(:[], :parent)
  end

  def self.parent_for_feature(identifier)
    find_by_identifier(feature_parent(identifier))
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

  def self.features
    @feature_cache ||= begin
      includes(:parent, :children).each_with_object({}) do |f, h|
        child_idents = f.children.collect(&:identifier)
        parent_ident = f.parent.identifier if f.parent
        details      = DETAIL_ATTRS.each_with_object({}) { |a, dh| dh[a] = f.send(a) }
        h[f.identifier] = {:parent => parent_ident, :children => child_idents, :details => details}
      end
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

  def self.seed_features(path = FIXTURE_PATH)
    fixture_yaml = feature_yaml(path)

    features = all.to_a.index_by(&:identifier)
    seen     = seed_from_hash(YAML.load_file(fixture_yaml), seen, nil, features)

    root_feature = MiqProductFeature.find_by(:identifier => 'everything')
    Dir.glob(path.join("*.yml")).each do |fixture|
      seed_from_hash(YAML.load_file(fixture), seen, root_feature)
    end

    deletes = where.not(:identifier => seen.values.flatten).destroy_all
    _log.info("Deleting product features: #{deletes.collect(&:identifier).inspect}") unless deletes.empty?
    seen
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

  def seed_vm_explorer_for_custom_roles
    return unless identifier == "vm_explorer"

    MiqUserRole.includes(:miq_product_features).select { |r| r.feature_identifiers.include?("vm") && !r.feature_identifiers.include?("vm_explorer") }.each do |role|
      role.miq_product_features << self
      role.save!
    end
  end

  def self.find_all_by_identifier(features)
    where(:identifier => features)
  end
end
