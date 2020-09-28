require 'ancestry'

class MiqAeNamespace < ApplicationRecord
  has_ancestry
  include MiqAeSetUserInfoMixin
  include MiqAeYamlImportExportMixin
  include RelativePathMixin

  EXPORT_EXCLUDE_KEYS = [/^id$/, /_id$/, /^created_on/, /^updated_on/,
                         /^updated_by/, /^reserved$/, /^commit_message/,
                         /^commit_time/, /^commit_sha/, /^ref$/, /^ref_type$/,
                         /^last_import_on/, /^source/, /^top_level_namespace/].freeze

  belongs_to :domain, :class_name => "MiqAeDomain", :inverse_of => false
  has_many :ae_classes, :class_name => "MiqAeClass",
           :foreign_key => :namespace_id, :dependent => :destroy, :inverse_of => :ae_namespace

  validates :name,
            :format                  => {:with => /\A[\w\.\-\$]+\z/i, :message => N_("may contain only alphanumeric and _ . - $ characters")},
            :presence                => true,
            :uniqueness_when_changed => {:scope => :ancestry, :case_sensitive => false}

  alias_attribute :fqname_sans_domain, :relative_path
  virtual_has_many :ae_namespaces
  alias ae_namespaces children

  before_validation :set_relative_path
  after_save :set_children_relative_path

  def parent
    parent_id == domain_id ? domain : super
  end

  def self.lookup_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    dname, *partial = split_fqname(fqname)
    domain_query = MiqAeDomain.unscoped.where(MiqAeDomain.arel_table[:name].lower.eq(dname.downcase)).where(:domain_id => nil)
    return domain_query.first if partial.empty?

    domain_id = domain_query.select(:id)
    query = include_classes ? includes(:ae_classes) : all
    query.find_by(:domain_id => domain_id, :lower_relative_path => partial.join("/").downcase)
  end

  singleton_class.send(:alias_method, :find_by_fqname, :lookup_by_fqname)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_fqname => :lookup_by_fqname)

  def self.find_or_create_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?

    found = lookup_by_fqname(fqname, include_classes)
    return found unless found.nil?

    parts = split_fqname(fqname)
    new_parts = [parts.pop]
    loop do
      break if parts.empty?

      found = lookup_by_fqname(parts.join('/'), include_classes)
      break unless found.nil?
      new_parts.unshift(parts.pop)
    end

    new_parts.each do |p|
      found = found ? create(:name => p, :parent => found) : MiqAeDomain.create(:name => p)
    end

    found
  end

  # TODO: broken since 2017
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

  def domain?
    root? && name != '$'
  end

  def self.display_name(number = 1)
    n_('Automate Namespace', 'Automate Namespaces', number)
  end

  private

  def set_relative_path
    return if root?

    self.domain_id ||= parent.domain_id || parent.id
    self.relative_path = [parent.relative_path, name].compact.join("/") if name_changed? || relative_path.nil?
  end

  def set_children_relative_path
    return unless saved_change_to_relative_path?

    ae_namespaces.each { |ns| ns.update!(:parent => self, :relative_path => nil) }
    ae_classes.each { |klass| klass.update!(:ae_namespace => self, :relative_path => nil) }
  end
end
