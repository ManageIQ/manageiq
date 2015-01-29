class MiqAeNamespace < MiqAeBase
  include MiqAeModelBase
  include MiqAeFsStore

  expose_columns :system, :enabled, :parent_id, :priority
  expose_columns :description, :display_name, :name
  expose_columns :id, :created_on, :created_by_user_id
  expose_columns :updated_on, :updated_by, :updated_by_user_id
  expose_columns :parent

  validate :uniqueness_of_name, :on => :create

  CLASS_HM_RELATIONS = {:class_name => "MiqAeClass", :foreign_key => :namespace_id, :belongs_to => "ae_namespace"}
  NAMESPACE_HM_RELATIONS = {:class_name => "MiqAeNamespace", :foreign_key => :parent_id, :belongs_to => "ae_namespace"}

  NS_YAML_FILES = [DOMAIN_YAML_FILE, NAMESPACE_YAML_FILE]
  def self.base_class
    MiqAeNamespace
  end

  def self.base_model
    MiqAeNamespace
  end

  def initialize(options = {})
    @attributes = HashWithIndifferentAccess.new(options)
    self.ae_namespace = @attributes.delete(:ae_namespace) if @attributes.key?(:ae_namespace)
  end

  def save
    context = persisted? ? :update : :create
    return false unless valid?(context)
    generate_id   unless id
    if domain? || name == "$"
      self.class.git_repository(name, true)
      fname    = DOMAIN_YAML_FILE
      obj_type = DOMAIN_OBJ_TYPE
    else
      fname    = NAMESPACE_YAML_FILE
      obj_type = NAMESPACE_OBJ_TYPE
    end
    hash = setup_envelope(obj_type)
    write(context, hash.to_yaml, fname).tap { |result| changes_applied if result }
  end

  def write(context, data, fname)
    path = fname == DOMAIN_YAML_FILE ? fname : self.class.relative_filename(fqname, fname)
    entry = {:path => path, :data => data}
    if context == :update && changes.key?('name')
      fname == DOMAIN_YAML_FILE ? mv_domain_dir(changes['name'][0], entry) :
                                  mv_namespace_dir(changes['name'][0], entry)
    else
      self.class.add_files_to_repo(domain_value, [entry])
    end
  end

  def mv_namespace_dir(old_name, entry)
    @fqname = "#{File.dirname(fqname)}/#{name}".downcase
    generate_id
    old_dir = self.class.relative_filename(File.dirname(fqname), "#{old_name}")
    new_dir = self.class.relative_filename(File.dirname(fqname), "#{name}")
    self.class.rename_ae_dir(domain_value, old_dir, new_dir, entry)
  end

  def mv_domain_dir(old_name, entry)
    @fqname = "/#{name}".downcase
    generate_id
    dirname = MiqAeDatastore::DATASTORE_DIRECTORY
    self.class.add_files_to_repo(domain_value, [entry])
    old_dir = Dir.entries(dirname).detect { |d| d.casecmp(old_name) == 0 }
    FileUtils.mv(File.join(dirname, old_dir), File.join(dirname, name)) == 0 if old_dir
  end

  def destroy
    self.class.delete_directory(self.class.fs_name(fqname))
    self
  end

  def self.destroy(id)
    obj = MiqAeNamespace.find(id)
    obj.destroy if obj
  end

  def generate_id
    self.id = self.class.fqname_to_id(fqname.downcase)
  end

  def self.find_by_fqname(fqname, _include_classes = true)
    return nil if fqname.blank?
    fqname = fqname.downcase
    fetch_ns_object(fqname)
  end

  def self.find_by_name(name)
    MiqAeDomain.fetch_by_name(name, MiqAeNamespace)
  end

  def self.first
    find_by_name('*')
  end

  def self.find_or_create_by_fqname(fqname, include_classes = true)
    return nil if fqname.blank?
    fqname = fqname[1..-1] if fqname[0] == '/'
    found  = find_by_fqname(fqname, include_classes)
    found.nil? ? create_sub_ns(fqname) : found
  end

  def self.create_sub_ns(fqname)
    parent = nil
    parts  = fqname.split('/')
    fqname = ""
    parts.each do |p|
      fqname = "#{fqname}/#{p}"
      found = find_by_fqname(fqname, false)
      if found
        parent = found
      else
        parent = create(:name => p, :parent_id => parent.nil? ? nil : parent.id)
      end
    end
    parent
  end

  def parent
    parent_id ? self.class.find(parent_id) : nil
  end

  def system?
    system
  end

  def enabled?
    enabled
  end

  def ancestors
    node, nodes = self, []
    nodes << node = node.parent while node.parent
    nodes
  end

  def fqname
    @fqname ||= attributes[:fqname]
    @fqname ||= "/#{ancestors.collect(&:name).reverse.push(name).join('/')}"
  end

  def fqname_from_objects
    @fqname_slow ||= "/#{ancestors.collect(&:name).reverse.push(name).join('/')}"
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
    @fqname_from_object ||= "/#{ancestors.collect(&:name).reverse.push(name).join('/')}"
    @fqname_from_object.split('/')[2..-1].join("/")
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

  def refresh_associations(_yaml_hash)
    @ns_proxy = MiqAeHasManyProxy.new(self, NAMESPACE_HM_RELATIONS, load_child_namespaces)
    @class_proxy = MiqAeHasManyProxy.new(self, CLASS_HM_RELATIONS, load_classes)
  end

  def ae_namespaces
    @ns_proxy ||= MiqAeHasManyProxy.new(self, NAMESPACE_HM_RELATIONS, load_child_namespaces)
  end

  def ae_classes
    @class_proxy ||= MiqAeHasManyProxy.new(self, CLASS_HM_RELATIONS, load_classes)
  end

  def load_child_namespaces(ns_filters = ['*'])
    load_namespace_children(MiqAeNamespace, NAMESPACE_YAML_FILE, ns_filters)
  end

  def load_classes(class_filters = ['*'])
    load_namespace_children(MiqAeClass, CLASS_YAML_FILE, class_filters)
  end

  def self.filename_to_fqname(filename)
    File.dirname(filename)
  end

  def self.count
    MiqAeDomain.fetch_count(MiqAeNamespace)
  end

  def self.find(id)
    return nil unless id
    find_by_fqname(id_to_fqname(id))
  end

  def self.find_by_id(id)
    find(id)
  end

  def self.fqname_to_filename(fqname)
    git_repo, path = git_repo_fqname(fqname)
    fname = domain_or_namespace_file(git_repo, path)
    "#{git_repo.base_name}/#{fname}"
  end

  def self.git_entry_exists?(fqname)
    git_repo, path = git_repo_fqname(fqname)
    entry = domain_or_namespace_entry(git_repo, path) if git_repo
    entry ? true : false
  end

  def self.fetch_ns_object(fqname)
    git_repo, path = git_repo_fqname(fqname)
    entry = domain_or_namespace_entry(git_repo, path) if git_repo
    load_ae_entry(git_repo, entry) if entry
  end

  def self.domain_or_namespace_file(git_repo, base_dir)
    flist = NS_YAML_FILES.map { |f| base_dir.empty? ? f : File.join(base_dir, f) }
    flist.detect { |f| git_repo.file_exists?(f) }
  end

  def self.domain_or_namespace_entry(git_repo, base_dir)
    flist = NS_YAML_FILES.map { |f| base_dir.empty? ? f : File.join(base_dir, f) }
    entry = nil
    flist.each do |f|
      next if entry
      entry = git_repo.find_entry(f)
    end
    entry
  end

  def self.all(_find_options = {})
    MiqAeDomain.all_domains
  end

  def self.find_tree(find_options = {})
    namespaces = all(find_options)
    ns_lookup = namespaces.each_with_object({}) do |h, ns|
      h[ns.id] = ns
      h
    end

    roots = []

    # Rails3 TODO: Review how we are doing this in light of changes to Associations
    # Assure all of the ae_namespaces reflections are loaded to prevent re-queries
    namespaces.each(&:ae_namespaces)

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

  def load_children
    load_child_namespaces
  end

  def children
    load_child_namespaces
  end

  # returns all siblings of the current node.
  #
  #   subchild1.siblings # => [subchild2]
  def siblings
    self_and_siblings - [self]
  end

  # Returns all siblings and a reference to the current node.
  #
  #   subchild1.self_and_siblings # => [subchild1, subchild2]
  def self_and_siblings
    parent ? parent.children : self.class.roots
  end
end
