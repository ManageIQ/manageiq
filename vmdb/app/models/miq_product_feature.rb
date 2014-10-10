class MiqProductFeature < ActiveRecord::Base
  acts_as_tree

  has_and_belongs_to_many :miq_user_roles, :join_table => :miq_roles_features

  validates_presence_of   :identifier
  validates_uniqueness_of :identifier

  FIXTURE_DIR  = File.join(Rails.root, "db/fixtures")
  FIXTURE_YAML = File.join(FIXTURE_DIR, "#{self.table_name}.yml")

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
    feat = self.features[identifier.to_s]
    feat[:parent] if feat
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
      self.all(:include => [:parent, :children]).inject({}) do |h,f|
        child_idents = f.children.collect { |c| c.identifier }
        parent_ident = f.parent.identifier if f.parent
        details      = DETAIL_ATTRS.inject({}) {|dh,a| dh[a] = f.send(a); dh}
        h[f.identifier] = {:parent => parent_ident, :children => child_idents, :details => details}
        h
      end
    end
  end

  def self.sort_children(children)
    # Build an array of arrays as [[feature_type, name, identifier], ...]
    c_array = children.collect { |c| [self.feature_details(c)[:feature_type], self.feature_details(c)[:name], c] }
    # Sort by feature_type and name forcing the ordering of feature_type to match FEATURE_TYPE_ORDER
    c_array.sort_by { |ftype, name, ident| [FEATURE_TYPE_ORDER.index(ftype), name] }.collect {|c| c.last}
  end

  def self.seed
    MiqRegion.my_region.lock do
      self.seed_features
    end
  end

  def self.seed_features
    log_header = "MIQ(#{self.name}.seed_features)"
    idents_from_hash = []
    self.seed_from_hash(YAML.load_file(FIXTURE_YAML), idents_from_hash)

    idents_from_db = self.all.collect(&:identifier)
    deletes = idents_from_db - (idents_from_db & idents_from_hash)
    unless deletes.empty?
      $log.info("#{log_header} Deleting product features: #{deletes.inspect}")
      self.destroy_all(:identifier => deletes)
    end
  end

  def self.seed_from_hash(hash, seen = [], parent=nil)
    log_header = "MIQ(#{self.name}.seed_from_hash)"
    children = hash.delete(:children) || []
    hash.delete(:parent_identifier)

    hash[:parent] = parent
    feature = self.find_by_identifier(hash[:identifier])
    if feature
      feature.attributes = hash
      if feature.changed?
        $log.info("#{log_header} Updating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
        feature.save
      end
    else
      $log.info("#{log_header} Creating product feature: Identifier: [#{hash[:identifier]}], Name: [#{hash[:name]}]")
      feature = self.create(hash)
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
end
