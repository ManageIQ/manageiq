class Classification < ApplicationRecord
  acts_as_tree

  belongs_to :tag

  virtual_column :name, :type => :string
  virtual_column :ns, :type => :string

  before_save    :save_tag
  before_destroy :validate_tag_mapping, :delete_tags_and_entries

  validates :description, :presence => true, :length => {:maximum => 255}, :unique_within_region => {:scope => :parent_id}

  NAME_MAX_LENGTH = 50
  validates :name, :presence => true, :length => {:maximum => NAME_MAX_LENGTH}
  validate :validate_format_of_name

  validate :validate_uniqueness_on_tag_name

  validates :syntax, :inclusion => {:in      => %w[string integer boolean],
                                    :message => "should be one of 'string', 'integer' or 'boolean'"}

  scope :visible,    -> { where(:show => true) }
  scope :read_only,  -> { where(:read_only => true) }
  scope :writeable,  -> { where(:read_only => false) }

  scope :is_category, -> { where(:parent_id => nil) }
  scope :is_entry,    -> { where.not(:parent_id => nil) }

  scope :with_writable_parents, -> { includes(:parent).where(:parents_classifications => { :read_only => false}) }

  DEFAULT_NAMESPACE = "/managed".freeze

  default_value_for :read_only,    false
  default_value_for :syntax,       "string"
  default_value_for :single_value, false
  default_value_for :show,         true

  FIXTURE_FILE = FIXTURE_DIR.join("classifications.yml")

  def self.hash_all_by_type_and_name(conditions = {})
    ret = {}

    where(conditions).is_category.includes(:tag).each do |c|
      ret.store_path(c.name, :category, c)
    end

    where(conditions).is_entry.includes(:tag, :parent => :tag).each do |e|
      ret.store_path(e.parent.name, :entry, e.name, e) unless e.parent.nil?
    end

    ret
  end

  def self.parent_ids(parent_ids)
    where(:parent_id => parent_ids)
  end

  def self.tags_arel
    Tag.arel_table
  end

  def self.with_tag_name
    select(arel_table[Arel.star], tags_arel[:name].as('tag_name'))
      .joins(:tag)
  end

  def self.managed
    with_tag_name.where(tags_arel[:name].matches_regexp("/managed/[^\\/]+$"))
  end

  attr_writer :ns

  def ns
    @ns ||= DEFAULT_NAMESPACE if new_record?

    return @ns if tag.nil?

    return @ns unless @ns.nil?

    if category?
      @ns = tag2ns(tag.name)
    else
      @ns = tag2ns(parent.tag.name) unless parent_id.nil?
    end
  end

  # Disable certain rubocop rules that don't really work here. Namely the
  # find_by warnings and .zero? warnings because of custom methods and
  # cases where objects could be zero or a real object.

  # rubocop:disable Rails/DynamicFindBy
  # rubocop:disable Style/NumericPredicate

  def self.classify(obj, category_name, entry_name, is_request = true)
    cat = Classification.lookup_by_name(category_name, obj.region_id)
    return " - FAILED. Tag category '#{category_name}' not found in region #{obj.region_id}" if cat.nil?

    ent = cat.find_entry_by_name(entry_name, obj.region_id)
    return " - FAILED. Tag name '#{entry_name}' not found  in region #{obj.region_id}" if ent.nil?

    return " - FAILED. Object already tagged with tag namespace set to 'none'" if obj.is_tagged_with?(ent.to_tag, :ns => "none")

    ent.assign_entry_to(obj, is_request)
    " - SUCCESS."
  end

  def self.unclassify(obj, category_name, entry_name, is_request = true)
    cat = Classification.lookup_by_name(category_name, obj.region_id)
    unless cat.nil?
      ent = cat.find_entry_by_name(entry_name, obj.region_id)
      ent.remove_entry_from(obj, is_request) unless ent.nil? || !obj.is_tagged_with?(ent.to_tag, :ns => "none")
    end
  end

  def self.classify_by_tag(obj, tag, is_request = true)
    parts = tag.split("/")
    raise _("Tag %{tag} is not a category entry") % {:tag => tag} unless parts[1] == "managed"

    entry_name = parts.pop
    category_name = parts.pop

    classify(obj, category_name, entry_name, is_request)
  end

  def self.unclassify_by_tag(obj, tag, is_request = true)
    parts = tag.split("/")
    raise _("Tag %{tag} is not a category entry") % {:tag => tag} unless parts[1] == "managed"

    entry_name = parts.pop
    category_name = parts.pop

    unclassify(obj, category_name, entry_name, is_request)
  end

  def self.bulk_reassignment(options = {})
    # options = {
    #   :model      => Target class name
    #   :object_ids => Array of target ids
    #   :add_ids    => Array of entry ids to be assigned to targets
    #   :delete_ids => Array of entry ids to be unassigned from targets
    # }

    model = options[:model].constantize
    targets = model.where(:id => options[:object_ids]).includes(:taggings, :tags)

    adds = where(:id => options[:add_ids]).includes(:tag)
    adds.each { |a| raise _("Classification add id: [%{id}] is not an entry") % {:id => a.id} if a.category? }

    deletes = where(:id => options[:delete_ids]).includes(:tag)
    deletes.each { |d| raise _("Classification delete id: [%{id}] is not an entry") % {:id => d.id} if d.category? }

    failed_deletes = Hash.new { |h, k| h[k] = [] }
    failed_adds    = Hash.new { |h, k| h[k] = [] }

    targets.each do |t|
      deletes.each do |d|
        _log.info("Removing entry name: [#{d.name}] from #{options[:model]} name: #{t.name}")

        begin
          d.remove_entry_from(t)
        rescue StandardError => err
          _log.error("Error occurred while removing entry name: [#{d.name}] from #{options[:model]} name: #{t.name}")
          _log.error("#{err.class} - #{err}")
          failed_deletes[t] << d
        end
      end

      adds.each do |a|
        _log.info("Adding entry name: [#{a.name}] to #{options[:model]} name: #{t.name}")

        begin
          a.assign_entry_to(t)
        rescue StandardError => err
          _log.error("Error occurred while adding entry name: [#{a.name}] to #{options[:model]} name: #{t.name}")
          _log.error("#{err.class} - #{err}")
          failed_adds[t] << a
        end
      end
    end

    if failed_deletes.any? || failed_adds.any?
      msg = _("Failures occurred during bulk reassignment.")
      failed_deletes.each do |target, deletes|
        names = deletes.collect(&:name).sort
        msg += _("  Unable to remove the following tags from %{class_name} %{id}: %{names}.") %
               {:class_name => target.class.name, :id => target.id, :names => names.join(", ")}
      end
      failed_adds.each do |target, adds|
        names = adds.collect(&:name).sort
        msg += _("  Unable to add the following tags to %{class_name} %{id}: %{names}.") %
               {:class_name => target.class.name, :id => target.id, :names => names.join(", ")}
      end
      raise msg
    end

    true
  end

  def self.get_tags_from_object(obj)
    tags = obj.tag_list(:ns => "/managed").split
    tags.delete_if { |t| t =~ /^\/folder_path_/ }
  end

  def self.create_category!(options)
    is_category.create!(options)
  end

  def self.categories(region_id = my_region_number, ns = DEFAULT_NAMESPACE)
    cats = is_category.in_region(region_id).includes(:tag, :children)
    cats.select { |c| c.ns == ns }
  end

  def self.category_names_for_perf_by_tag(region_id = my_region_number, ns = DEFAULT_NAMESPACE)
    in_region(region_id).is_category.where(:perf_by_tag => true)
      .includes(:tag)
      .collect { |c| c.name if c.tag2ns(c.tag.name) == ns }
      .compact
  end

  def self.find_assigned_entries(obj, ns = DEFAULT_NAMESPACE)
    unless obj.respond_to?("tag_with")
      raise _("Class '%{name}' is not eligible for classification") % {:name => obj.class}
    end

    tag_ids = obj.tagged_with(:ns => ns).collect(&:id)
    where(:tag_id => tag_ids)
  end

  def self.first_cat_entry(name, obj)
    cat = lookup_by_name(name, obj.region_id)
    return nil unless cat

    find_assigned_entries(obj).each do |e|
      return e if e.parent_id == cat.id
    end
    nil
  end

  # Splits a fully qualified tag into the namespace, category, and entry
  def self.tag_name_split(tag_name)
    parts = tag_name.split("/")
    parts.shift
    parts
  end

  # Splits a fully qualified tag into the namespace, category object, and entry object
  def self.tag_name_to_objects(tag_name)
    ns, cat, entry = tag_name_split(tag_name)
    cat_obj = lookup_by_name(cat)
    entry_obj = cat_obj && cat_obj.find_entry_by_name(entry)
    return ns, cat_obj, entry_obj
  end

  # Builds the given tag into a format usable when calling to_model_hash.
  def self.tag_to_model_hash(tag)
    ns, cat, entry = tag_name_to_objects(tag.name)

    h = {:id => tag.id, :name => tag.name, :namespace => ns}
    %w[id name description single_value].each { |m| h[:"category_#{m}"] = cat.send(m) } unless cat.nil?
    %w[id name description].each { |m| h[:"entry_#{m}"] = entry.send(m) } unless entry.nil?
    h
  end

  def add_entry(options)
    raise _("entries can only be added to classifications") unless category?
    # Inherit from parent classification
    options.merge!(:read_only => read_only, :syntax => syntax, :single_value => single_value, :ns => ns)
    children.create!(options)
  end

  def entries
    children
  end

  def lookup_by_entry(type)
    raise _("method is only available for an entry") if category?
    klass = type.constantize
    unless klass.respond_to?("find_tagged_with")
      raise _("Class '%{type}' is not eligible for classification") % {:type => type}
    end

    klass.find_tagged_with(:any => name, :ns => ns, :cat => parent.name)
  end

  alias find_by_entry lookup_by_entry
  Vmdb::Deprecation.deprecate_methods(self, :find_by_entry => :lookup_by_entry)

  def assign_entry_to(obj, is_request = true)
    raise _("method is only available for an entry") if category?
    unless obj.respond_to?("tag_with")
      raise _("Class '%{name}' is not eligible for classification") % {:name => obj.class}
    end

    enforce_policy(obj, :request_assign_company_tag) if is_request
    if parent.single_value?
      obj.tag_with(name, :ns => ns, :cat => parent.name)
    else
      obj.tag_add(name, :ns => ns, :cat => parent.name)
    end
    obj.reload
    enforce_policy(obj, :assigned_company_tag)
  end

  def remove_entry_from(obj, is_request = true)
    enforce_policy(obj, :request_unassign_company_tag) if is_request
    tags = obj.tag_list(:ns => ns, :cat => parent.name).split
    tags.delete(name)
    obj.tag_with(tags.join(" "), :ns => ns, :cat => parent.name)
    obj.reload
    enforce_policy(obj, :unassigned_company_tag)
  end

  def to_tag
    tag.name unless tag.nil?
  end

  def category?
    parent_id.nil?
  end

  def category
    parent.try(:name)
  end

  def tag_name
    attribute(:tag_name)
  end

  def name
    @name ||= tag2name(tag_name || tag.name)
  end

  attr_writer :name

  def self.lookup_category_by_description(description, region_id = my_region_number)
    is_category.in_region(region_id).find_by(:description => description)
  end

  def find_entry_by_name(name, region_id = my_region_number)
    self.class.lookup_by_name(name, region_id, ns, self)
  end

  # @param parent_id [Integer|Parent] node for the parent. This is only passed in for find_entry_by_name
  def self.lookup_by_name(name, region_id = my_region_number, name_space = DEFAULT_NAMESPACE, parent_id = nil)
    lookup_by_names([name], region_id, name_space, parent_id).first
  end

  singleton_class.send(:alias_method, :find_by_name, :lookup_by_name)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_name => :lookup_by_name)

  # @param parent_id [Integer|Parent] node for the parent. This is only passed in for find_entry_by_name
  def self.lookup_by_names(names, region_id = my_region_number, name_space = DEFAULT_NAMESPACE, parent_id = nil)
    tag_names = names.map { |name| name2tag(name, parent_id, name_space) }
    # NOTE: tags is a subselect - not an array of ids
    tags = Tag.in_region(region_id).where(:name => tag_names).select(:id)
    where(:tag_id => tags)
  end

  singleton_class.send(:alias_method, :find_by_names, :lookup_by_names)
  Vmdb::Deprecation.deprecate_methods(singleton_class, :find_by_names => :lookup_by_names)

  def tag2ns(tag)
    unless tag.nil?
      ta = tag.split("/")
      ta[0..(ta.length - 2)].join("/")
    end
  end

  def enforce_policy(obj, event)
    return unless MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES.include?(obj.class.base_class)
    return if parent.name == "power_state" # special case for old power state classifications - don't enforce policy since this is being changed by the system

    mode = event.to_s.split("_").first # request/after
    begin
      MiqEvent.raise_evm_event(obj, event)
    rescue MiqException::PolicyPreventAction => err
      if mode == "request"
        # if it's the "before_..." event we can still prevent it from proceeding. Otherwise it's too late.
        _log.info("Event: [#{event}], #{err.message}")
        raise
      end
    rescue Exception => err
      _log.log_backtrace(err)
      raise
    end
  end

  def self.export_to_array
    categories.inject([]) do |a, c|
      a.concat(c.export_to_array)
    end
  end

  def self.export_to_yaml
    export_to_array.to_yaml
  end

  def export_to_array
    h = attributes.except(*%w(id tag_id reserved parent_id))
    h["name"] = name
    h["entries"] = entries.collect(&:export_to_array).flatten if category?
    [h]
  end

  def export_to_yaml
    export_to_array.to_yaml
  end

  def self.import_from_hash(classification, parent = nil)
    raise _("No Classification to Import") if classification.nil?

    stats = {"categories" => 0, "entries" => 0}

    if parent.nil? # category
      cat = lookup_by_name(classification["name"])
      if cat
        _log.info("Skipping Classification (already in DB): Category: name=[#{classification["name"]}]")
        return stats
      end

      _log.info("Importing Classification: Category: name=[#{classification["name"]}]")

      classification.delete("parent_id")
      entries = classification.delete("entries")
      cat = create(classification)
      stats["categories"] += 1
      entries.each do |e|
        stat, _e = import_from_hash(e, cat)
        stats.each_key { |k| stats[k] += stat[k] }
      end

      return stats, cat
    else
      entry = parent.find_entry_by_name(classification["name"])
      if entry
        _log.info("Skipping Classification (already in DB): Category: name: [#{parent.name}], Entry: name=[#{classification["name"]}]")
        return stats
      end

      _log.info("Importing Classification: Category: name: [#{parent.name}], Entry: name=[#{classification["name"]}]")
      entry = create(classification.merge("parent_id" => parent.id))
      stats["entries"] += 1

      return stats, entry
    end
  end

  def self.import_from_yaml(fd)
    stats = {"categories" => 0, "entries" => 0}

    input = YAML.load(fd)
    input.each do |c|
      stat, _c = import_from_hash(c)
      stats.each_key { |k| stats[k] += stat[k] }
    end

    stats
  end

  # rubocop:disable Rails/SkipsModelValidations

  def self.seed
    YAML.load_file(FIXTURE_FILE).each do |c|
      category = lookup_by_name(c[:name], my_region_number, (c[:ns] || DEFAULT_NAMESPACE))
      next if category

      category = is_category.new(c.except(:entries))
      next unless category.valid? # HACK: Skip seeding if categories aren't valid/unique
      _log.info("Creating category #{c[:name]}")
      category.save!
      add_entries_from_hash(category, c[:entries])
    end
  end

  # rubocop:enable Rails/SkipsModelValidations

  def self.sanitize_name(name)
    name.downcase.tr('^a-z0-9_:', '_')[0, NAME_MAX_LENGTH]
  end

  def self.display_name(number = 1)
    n_('Category', 'Categories', number)
  end

  def self.tag2human(tag)
    c, e = tag.split("/")[2..-1]

    cat = lookup_by_name(c)
    cname = cat.nil? ? c.titleize : cat.description

    ename = e.titleize
    unless cat.nil?
      ent = cat.find_entry_by_name(e)
      ename = ent.description unless ent.nil?
    end

    "#{cname}: #{ename}"
  end

  def self.add_entries_from_hash(cat, entries)
    entries.each do |entry|
      ent = cat.find_entry_by_name(entry[:name])
      ent ? ent.update!(entry) : cat.add_entry(entry)
    end
  end

  private_class_method :add_entries_from_hash

  def validate_uniqueness_on_tag_name
    tag_name = Classification.name2tag(name, parent, ns)
    exist_scope = Classification.includes(:tag).where(:tags => {:name => tag_name}).merge(Tag.in_region(region_id))
    exist_scope = exist_scope.where.not(:id => id) unless new_record?

    errors.add("name", "has already been taken") if exist_scope.exists?
  end

  def self.name2tag(name, parent_id = nil, ns = DEFAULT_NAMESPACE)
    if parent_id.nil?
      File.join(ns, name)
    else
      c = parent_id.kind_of?(Classification) ? parent_id : Classification.find(parent_id)
      File.join(ns, c.name, name) if c
    end
  end

  private

  def validate_format_of_name
    unless (name =~ /[^a-z0-9_:]/).nil?
      errors.add("name", "must be lowercase alphanumeric characters, colons and underscores without spaces")
    end
  end

  def tag2name(tag)
    File.split(tag).last unless tag.nil?
  end

  def find_tag
    tag_name = Classification.name2tag(name, parent, ns)
    Tag.in_region(region_id).find_by(:name => tag_name)
  end

  def save_tag
    tag_name = Classification.name2tag(name, parent, ns)
    if tag_id.present? || tag.present?
      tag.update(:name => tag_name) unless tag.name == tag_name
    else
      self.tag = Tag.in_region(region_id).find_or_create_by(:name => tag_name)
    end
  end

  def delete_all_entries
    entries.each do |e|
      e.delete_assignments
      e.delete_tag_and_taggings
    end
  end

  def delete_assignments
    AssignmentMixin.all_assignments(tag.name).destroy_all
  end

  def delete_tag_and_taggings
    tag = find_tag
    return if tag.nil?

    tag.destroy
  end

  def delete_tags_and_entries
    if category?
      delete_all_entries
    else # entry
      delete_assignments
    end

    delete_tag_and_taggings
  end

  def validate_tag_mapping
    if tag&.provider_tag_mappings&.any?
      errors.add("", _("A Tag Mapping exists for this category and must be removed before deleting"))
      throw :abort
    end
  end

  # rubocop:enable Style/NumericPredicate
  # rubocop:enable Rails/DynamicFindBy
end
