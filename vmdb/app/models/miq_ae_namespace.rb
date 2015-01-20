class MiqAeNamespace < ActiveRecord::Base
  acts_as_tree
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  belongs_to :parent,        :class_name => "MiqAeNamespace",  :foreign_key => :parent_id
  has_many   :ae_namespaces, :class_name => "MiqAeNamespace",  :foreign_key => :parent_id,    :dependent => :destroy
  has_many   :ae_classes, -> { includes([:ae_methods, :ae_fields, :ae_instances]) },    :class_name => "MiqAeClass",      :foreign_key => :namespace_id, :dependent => :destroy

  validates_presence_of   :name
  validates_format_of     :name, :with => /\A[A-Za-z0-9_\.\-\$]+\z/i
  validates_uniqueness_of :name, :scope => :parent_id

  def self.find_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    fqname   = fqname[0] == '/' ? fqname : "/#{fqname}"
    fqname   = fqname.downcase
    last     = fqname.split('/').last
    low_name = arel_table[:name].lower
    query = include_classes ? includes(:parent, :ae_classes) : self
    query.where(low_name.eq(last)).detect { |namespace| namespace.fqname.downcase == fqname }
  end

  def self.find_or_create_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    fqname   = fqname[1..-1] if fqname[0] == '/'
    found = find_by_fqname(fqname, include_classes)
    return found unless found.nil?

    parts = fqname.split('/')
    new_parts = [parts.pop]
    loop do
      found = find_by_fqname(parts.join('/'), include_classes)
      break unless found.nil?
      new_parts.unshift(parts.pop)
      break if parts.empty?
    end

    new_parts.each do |p|
      found = self.create(:name => p, :parent_id => found.nil? ? nil : found.id)
    end

    return found
  end

  def self.find_tree(find_options = {})
    namespaces = self.where(find_options)
    ns_lookup = namespaces.inject({}) { |h, ns| h[ns.id] = ns; h }

    roots = []

    # Rails3 TODO: Review how we are doing this in light of changes to Associations
    # Assure all of the ae_namespaces reflections are loaded to prevent re-queries
    namespaces.each { |ns| ns.ae_namespaces.loaded }

    namespaces.each do |ns|
      if ns.parent_id.nil?
        roots << ns
      else
        # Manually fill in the ae_namespaces reflections of the parents
        parent = ns_lookup[ns.parent_id]
        parent.ae_namespaces.target.push(ns) unless parent.nil?
      end
    end

    return roots
  end

  def fqname
    @fqname ||= "/#{ancestors.collect(&:name).reverse.push(name).join('/')}"
  end

  def editable?
    return !system? if domain?
    return false if ancestors.any?(&:system?)
    !system?
  end

  def ns_fqname
    return nil if fqname == domain_name
    fqname.sub(domain_name.to_s, '')
  end

  def fqname_sans_domain
    fqname.split('/')[2..-1].join("/")
  end

  def domain_name
    domain.try(:name)
  end

  def domain
    if domain?
      self
    elsif (ns = ancestors.last) && ns.domain?
      ns
    end
  end

  def domain?
    parent_id.nil? && name != '$'
  end

end
