require 'ancestry'
require 'ancestry_patch'

class MiqAeNamespace < ApplicationRecord
  has_ancestry
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin

  EXPORT_EXCLUDE_KEYS = [/^id$/, /_id$/, /^created_on/, /^updated_on/,
                         /^updated_by/, /^reserved$/, /^commit_message/,
                         /^commit_time/, /^commit_sha/, /^ref$/, /^ref_type$/,
                         /^last_import_on/, /^source/, /^top_level_namespace/].freeze

  has_many :ae_classes, -> { includes([:ae_methods, :ae_fields, :ae_instances]) }, :class_name => "MiqAeClass",
           :foreign_key => :namespace_id, :dependent => :destroy, :inverse_of => false

  validates :name,
            :format     => {:with => /\A[\w\.\-\$]+\z/i, :message => N_("may contain only alphanumeric and _ . - $ characters")},
            :presence   => true,
            :uniqueness => {:scope => :ancestry, :case_sensitive => false}

  alias ae_namespaces children
  virtual_has_many :ae_namespaces

  def self.lookup_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    fqname = fqname[0] == '/' ? fqname : "/#{fqname}"
    fqname = fqname.downcase
    last = fqname.split('/').last
    low_name = arel_table[:name].lower

    query = include_classes ? includes(:ae_classes) : all
    query.where(low_name.eq(last)).detect { |namespace| namespace.fqname.downcase == fqname }
  end

  singleton_class.send(:alias_method, :find_by_fqname, :lookup_by_fqname)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_fqname => :lookup_by_fqname)

  def self.find_or_create_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    fqname = fqname[1..-1] if fqname[0] == '/'
    found = lookup_by_fqname(fqname, include_classes)
    return found unless found.nil?

    parts = fqname.split('/')
    new_parts = [parts.pop]
    loop do
      break if parts.empty?

      found = lookup_by_fqname(parts.join('/'), include_classes)
      break unless found.nil?
      new_parts.unshift(parts.pop)
    end

    new_parts.each do |p|
      found = found ? create(:name => p, :parent => found) : create(:name => p)
    end

    found
  end

  def self.find_tree(find_options = {})
    namespaces = where(find_options)
    ns_lookup = namespaces.inject({}) do |h, ns|
      h[ns.id] = ns
      h
    end

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

    roots
  end

  def fqname
    @fqname ||= "/#{path.pluck(:name).join('/')}"
  end

  def editable?(user = User.current_user)
    raise ArgumentError, "User not provided to editable?" unless user
    return false if domain? && user.current_tenant.id != tenant_id
    return source == MiqAeDomain::USER_SOURCE if domain?
    ancestors.all? { |a| a.editable?(user) }
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
    root if root.domain?
  end

  def domain?
    root? && name != '$'
  end

  def self.display_name(number = 1)
    n_('Automate Namespace', 'Automate Namespaces', number)
  end
end
