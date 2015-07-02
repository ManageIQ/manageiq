class MiqProductFeature < ActiveRecord::Base
  acts_as_tree

  has_and_belongs_to_many :miq_user_roles, :join_table => :miq_roles_features

  validates_presence_of   :identifier
  validates_uniqueness_of :identifier

  FIXTURE_DIR  = File.join(Rails.root, "db/fixtures")
  FIXTURE_PATH = File.join(FIXTURE_DIR, self.table_name)
  FIXTURE_YAML = "#{FIXTURE_PATH}.yml"

  DETAIL_ATTRS = [
    :name,
    :description,
    :feature_type,
    :hidden,
    :protected
  ]

  FEATURE_TYPE_ORDER = ["view", "control", "admin", "node"]

  def self.feature_root
    self.features.keys.detect {|k| self.feature_parent(k).nil?}
  end

  def self.feature_parent(identifier)
    features[identifier.to_s].try(:[], :parent)
  end

  def self.parent_for_feature(identifier)
    find_by_identifier(feature_parent(identifier))
  end

  def self.feature_children(identifier)
    feat = self.features[identifier.to_s]
    children = (feat && !feat[:hidden] ? feat[:children] : [])
    self.sort_children(children)
  end

  def self.feature_all_children(identifier)
    result = children = self.feature_children(identifier)
    children.collect { |c| result += self.feature_all_children(c) unless self.feature_children(c).empty? }

    self.sort_children(result.flatten.compact)
  end

  def self.feature_details(identifier)
    feat = self.features[identifier.to_s]
    feat[:details] if feat && !feat[:hidden]
  end

  def self.feature_exists?(ident)
    self.features.has_key?(ident)
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
    # Build an array of arrays as [[feature_type, name, identifier], ...]
    c_array = children.collect { |c| [self.feature_details(c)[:feature_type], self.feature_details(c)[:name], c] }
    # Sort by feature_type and name forcing the ordering of feature_type to match FEATURE_TYPE_ORDER
    c_array.sort_by { |ftype, name, ident| [FEATURE_TYPE_ORDER.index(ftype), name] }.collect(&:last)
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.seed_features
    end
  end

  def self.seed_features
    idents_from_hash = []
    self.seed_from_hash(YAML.load_file(FIXTURE_YAML), idents_from_hash)

    root_feature = MiqProductFeature.where(:identifier => 'everything').first
    Dir.glob(File.join(FIXTURE_PATH, "*.yml")).each do |fixture|
      self.seed_from_hash(YAML.load_file(fixture), idents_from_hash, root_feature)
    end

    idents_from_db = self.all.collect(&:identifier)
    deletes = idents_from_db - (idents_from_db & idents_from_hash)
    unless deletes.empty?
      _log.info("Deleting product features: #{deletes.inspect}")
      self.destroy_all(:identifier => deletes)
    end
  end

  def self.seed_from_hash(hash, seen = [], parent=nil)
    children = hash.delete(:children) || []
    hash.delete(:parent_identifier)

    hash[:parent] = parent
    feature = self.find_by_identifier(hash[:identifier])
    if feature
      feature.attributes = hash
      if feature.changed?
        _log.info("Updating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
        feature.save
      end
    else
      _log.info("Creating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
      feature = self.create(hash.except(:id))
      feature.seed_vm_explorer_for_custom_roles
    end
    seen << hash[:identifier]

    children.each do |child|
      self.seed_from_hash(child, seen, feature)
    end
  end

  def seed_vm_explorer_for_custom_roles
    return unless self.identifier == "vm_explorer"

    MiqUserRole.all.select { |r| r.feature_identifiers.include?("vm") && !r.feature_identifiers.include?("vm_explorer") }.each do |role|
      role.miq_product_features << self
      role.save!
    end
  end

  def self.find_all_by_identifier(features)
    where(:identifier => features)
  end
end
