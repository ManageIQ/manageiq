class Classification < ActiveRecord::Base
  acts_as_tree

  belongs_to :tag

  before_save    :save_tag
  before_destroy :delete_tags_and_entries
  validate       :validate_format_of_name, :validate_uniqueness_on_tag_name

  validates_uniqueness_of :description, :scope => [:parent_id],
    :if => Proc.new { |c|
      cond = ["parent_id = ? AND description = ?", c.parent_id, c.description]
      unless c.new_record?
        cond.first << " AND id != ?"
        cond       << c.id
      end
      c.class.in_my_region.exists?(cond)
    }
  validates_presence_of :name, :description
  validates_length_of :name, :maximum => 30, :message => "must not exceed 30 characters"
  validates_length_of :description, :maximum => 255, :message => "must not exceed 255 characters"
  validates_inclusion_of :syntax,
    :in => %w{ string integer boolean },
    :message => "should be one of 'string', 'integer' or 'boolean'"

  DEFAULT_NAMESPACE = "/managed"

  default_value_for :read_only,    false
  default_value_for :syntax,       "string"
  default_value_for :single_value, false
  default_value_for :show,         true

  FIXTURE_FILE = File.join(Rails.root, "db/fixtures/classifications.yml")

  def self.hash_all_by_type_and_name(conditions = {})
    ret = {}

    self.find(:all, :conditions => conditions.merge(:parent_id => 0), :include => :tag).each do |c|
      ret.store_path(c.name, :category, c)
    end

    self.find(:all, :conditions => merge_conditions(conditions, "parent_id != 0"), :include => [:tag, { :parent => :tag }]).each do |e|
      ret.store_path(e.parent.name, :entry, e.name, e) unless e.parent.nil?
    end

    ret
  end

  def ns=(namespace)
    @ns = namespace
  end

  def ns
    @ns ||= DEFAULT_NAMESPACE if self.new_record?

    # @ns = tag2ns(self.tag.name) unless self.tag.nil?
    return @ns if self.tag.nil?

    return @ns unless @ns.nil?

    if category?
      @ns = tag2ns(self.tag.name)
    else
      @ns = tag2ns(self.parent.tag.name) unless self.parent_id.nil?
    end
  end

  def self.classify(obj, category_name, entry_name, is_request=true)
    cat = Classification.find_by_name(category_name, obj.region_id)
    unless cat.nil?
      ent = cat.find_entry_by_name(entry_name, obj.region_id)
      ent.assign_entry_to(obj, is_request) unless ent.nil? || obj.is_tagged_with?(ent.to_tag, :ns=>"none")
    end
  end

  def self.unclassify(obj, category_name, entry_name, is_request=true)
    cat = Classification.find_by_name(category_name, obj.region_id)
    unless cat.nil?
      ent = cat.find_entry_by_name(entry_name, obj.region_id)
      ent.remove_entry_from(obj, is_request) unless ent.nil? || !obj.is_tagged_with?(ent.to_tag, :ns=>"none")
    end
  end

  def self.classify_by_tag(obj, tag, is_request=true)
    parts = tag.split("/")
    raise "Tag #{tag} is not a category entry" unless parts[1] == "managed"

    entry_name = parts.pop
    category_name = parts.pop

    self.classify(obj, category_name, entry_name, is_request)
  end

  def self.unclassify_by_tag(obj, tag, is_request=true)
    parts = tag.split("/")
    raise "Tag #{tag} is not a category entry" unless parts[1] == "managed"

    entry_name = parts.pop
    category_name = parts.pop

    self.unclassify(obj, category_name, entry_name, is_request)
  end

  def self.bulk_reassignment(options = {})
    # options = {
    #   :model      => Target class name
    #   :object_ids => Array of target ids
    #   :add_ids    => Array of entry ids to be assigned to targets
    #   :delete_ids => Array of entry ids to be unassigned from targets
    # }
    log_prefix = "MIQ(Classification.bulk_reassignment)"

    model = options[:model].constantize
    targets = model.find_all_by_id(options[:object_ids], :include => [:taggings, :tags])

    adds = self.find_all_by_id(options[:add_ids], :include => [:tag])
    adds.each {|a| raise "Classification add id: [#{a.id}] is not an entry" if a.category?}

    deletes = self.find_all_by_id(options[:delete_ids], :include => [:tag])
    deletes.each {|d| raise "Classification delete id: [#{d.id}] is not an entry" if d.category?}

    failed_deletes = Hash.new { |h, k| h[k] = [] }
    failed_adds    = Hash.new { |h, k| h[k] = [] }

    targets.each do |t|
      deletes.each do |d|
        $log.info("#{log_prefix} Removing entry name: [#{d.name}] from #{options[:model]} name: #{t.name}")

        begin
          d.remove_entry_from(t)
        rescue => err
          $log.error("#{log_prefix} Error occurred while removing entry name: [#{d.name}] from #{options[:model]} name: #{t.name}")
          $log.error("#{log_prefix} #{err.class} - #{err}")
          failed_deletes[t] << d
        end
      end

      adds.each do |a|
        $log.info("#{log_prefix} Adding entry name: [#{a.name}] to #{options[:model]} name: #{t.name}")

        begin
          a.assign_entry_to(t)
        rescue => err
          $log.error("#{log_prefix} Error occurred while adding entry name: [#{a.name}] to #{options[:model]} name: #{t.name}")
          $log.error("#{log_prefix} #{err.class} - #{err}")
          failed_adds[t] << a
        end
      end
    end

    if failed_deletes.any? || failed_adds.any?
      msg = "Failures occurred during bulk reassignment."
      failed_deletes.each do |target, deletes|
        names = deletes.collect(&:name).sort
        msg << "  Unable to remove the following tags from #{target.class.name} #{target.id}: #{names.join(", ")}."
      end
      failed_adds.each do |target, adds|
        names = adds.collect(&:name).sort
        msg << "  Unable to add the following tags to #{target.class.name} #{target.id}: #{names.join(", ")}."
      end
      raise msg
    end

    true
  end

  def self.get_tags_from_object(obj)
    tags = obj.tag_list(:ns=>"/managed").split
    tags.delete_if {|t| t =~ /^\/folder_path_/}
  end

  def self.create_category!(options)
    self.create!(options.merge(:parent_id => 0))
  end

  def self.categories(region_id = self.my_region_number, ns = DEFAULT_NAMESPACE)
    result = []
    if region_id
      cats = Classification.in_region(region_id).find(:all, :conditions => "classifications.parent_id = 0", :include => [:tag, :children])
    else
      cats = Classification.find(:all, :conditions => "classifications.parent_id = 0", :include => [:tag, :children])
    end
    cats.each { |c| result.push(c) if c.tag2ns(c.tag.name) == ns }
    result
  end

  def self.category_names_for_perf_by_tag(region_id = self.my_region_number, ns = DEFAULT_NAMESPACE)
    self.in_region(region_id)
      .where(:parent_id => 0, :perf_by_tag => true)
      .includes(:tag)
      .collect { |c| c.name if c.tag2ns(c.tag.name) == ns }
      .compact
  end

  def self.find_assigned_entries(obj, ns=DEFAULT_NAMESPACE)
    raise "Class '#{obj.class}' is not eligible for classification" unless obj.respond_to?("tag_with")

    tag_ids = obj.tagged_with(:ns => ns).collect {|tag| tag.id}
    self.find_all_by_tag_id(tag_ids) rescue []
  end

  def self.first_cat_entry(name, obj)
    cat = self.find_by_name(name, obj.region_id)
    return nil unless cat

    self.find_assigned_entries(obj).each {|e|
      return e if e.parent_id == cat.id
    }
    nil
  end

  def self.all_cat_entries(name, obj)
    cat = self.find_by_name(name, obj.region_id)
    return [] unless cat

    self.find_assigned_entries(obj).collect {|e| e if e.parent_id == cat.id}.compact
  end

  # Splits a fully qualified tag into the namespace, category, and entry
  def self.tag_name_split(tag_name)
    parts = tag_name.split("/")
    parts.shift
    return *parts
  end

  # Splits a fully qualified tag into the namespace, category object, and entry object
  def self.tag_name_to_objects(tag_name)
    ns, cat, entry = self.tag_name_split(tag_name)
    cat_obj = self.find_by_name(cat)
    entry_obj = cat_obj.nil? ? nil : cat_obj.find_entry_by_name(entry)
    return ns, cat_obj, entry_obj
  end

  # Builds the given tag into a format usable when calling to_model_hash.
  def self.tag_to_model_hash(tag)
    ns, cat, entry = self.tag_name_to_objects(tag.name)

    h = {:id => tag.id, :name => tag.name, :namespace => ns}
    %w{id name description single_value}.each { |m| h[:"category_#{m}"] = cat.send(m) } unless cat.nil?
    %w{id name description}.each { |m| h[:"entry_#{m}"] = entry.send(m) } unless entry.nil?
    h
  end

  def add_entry(options)
    raise "entries can only be added to classifications" unless self.category?
    # Inherit from parent classification
    options.merge!(:read_only => self.read_only, :syntax => self.syntax, :single_value => self.single_value, :ns => self.ns)
    self.children.create(options)
  end

  def entries
    self.children
  end

  def find_by_entry(type)
    raise "method is only available for an entry" if self.category?
    klass = type.constantize
    raise "Class '#{type}' is not eligible for classification" unless klass.respond_to?("find_tagged_with")

    klass.find_tagged_with(:any => self.name, :ns => self.ns, :cat => self.parent.name)
  end

  def assign_entry_to(obj, is_request=true)
    raise "method is only available for an entry" if self.category?
    raise "Class '#{obj.class}' is not eligible for classification" unless obj.respond_to?("tag_with")

    self.enforce_policy(obj, :request_assign_company_tag) if is_request
    if self.parent.single_value?
      obj.tag_with(self.name, :ns => self.ns, :cat => self.parent.name)
    else
      obj.tag_add(self.name, :ns => self.ns, :cat => self.parent.name)
    end
    obj.reload
    self.enforce_policy(obj, :assigned_company_tag)
  end

  def remove_entry_from(obj, is_request=true)
    self.enforce_policy(obj, :request_unassign_company_tag) if is_request
    tags = obj.tag_list(:ns => self.ns, :cat => self.parent.name).split
    tags.delete(self.name)
    obj.tag_with(tags.join(" "), :ns => self.ns, :cat => self.parent.name)
    obj.reload
    self.enforce_policy(obj, :unassigned_company_tag)
  end

  def to_tag
    self.tag.name unless self.tag.nil?
  end

  def category?
    self.parent_id == 0
  end

  def category
    self.parent.try(:name)
  end

  def name
    @name ||= tag2name(self.tag.name)
  end

  def name=(name)
    @name = name
  end

  def find_entry_by_name(name, region_id = self.my_region_number)
    tag = Tag.in_region(region_id).find_by_name(Classification.name2tag(name, self.id, self.ns))
    tag.nil? ? nil : self.class.find_by_tag_id(tag.id)
  end

  def self.find_by_name(name, region_id = self.my_region_number, ns = DEFAULT_NAMESPACE)
    if region_id.nil?
      tag = Tag.find_by_name(Classification.name2tag(name, 0, ns))
    else
      tag = Tag.in_region(region_id).find_by_name(Classification.name2tag(name, 0, ns))
    end
    tag.nil? ? nil : self.find_by_tag_id(tag.id)
  end

  def tag2ns(tag)
    unless tag.nil?
      ta = tag.split("/")
      ta[0..(ta.length-2)].join("/")

      # tnew = []
      # tag.split("/").each {|level|
      #   p "level=#{level}"
      #   tnew.push(level) unless level == self.name
      #   p "level=#{level}, #{tnew.inspect}, #{(level == self.name)}"
      # }
      # tnew.join("/")
    end
  end

  def enforce_policy(obj, event)
    return unless MiqEvent::SUPPORTED_POLICY_AND_ALERT_CLASSES.include?(obj.class.base_class)
    return if self.parent.name == "power_state" # special case for old power state classifications - don't enforce policy since this is being changed by the system

    mode = event.to_s.split("_").first # request/after
    begin
      MiqEvent.raise_evm_event(obj, event)
    rescue MiqException::PolicyPreventAction => err
      if mode == "request"
        # if it's the "before_..." event we can still prevent it from proceeding. Otherwise it's too late.
        $log.info("MIQ(Classification#enforce_policy) Event: [#{event}], #{err.message}")
        raise
      end
    rescue Exception => err
      $log.log_backtrace(err)
      raise
    end
  end

  def self.export_to_array
    result = self.categories.inject([]) do |a,c|
      a.concat c.export_to_array
    end
  end

  def self.export_to_yaml
    a = self.export_to_array
    a.to_yaml
  end

  def export_to_array
    h = self.attributes
    h["name"] = self.name
    if category?
      ["id", "tag_id", "reserved"].each { |k| h.delete(k) }
      h["entries"] = self.entries.collect { |e| e.export_to_array }.flatten
    else
      ["id", "tag_id", "reserved", "parent_id"].each { |k| h.delete(k) }
    end
    return [ h ]
  end

  def export_to_yaml
    a = export_to_array
    a.to_yaml
  end

  def self.import_from_hash(classification, parent=nil)
    raise "No Classification to Import" if classification.nil?

    stats = { "categories" => 0, "entries" => 0 }

    if classification["parent_id"] == 0 # category
      cat = self.find_by_name(classification["name"])
      if cat
        $log.info("Skipping Classification (already in DB): Category: name=[#{classification["name"]}]")
        return stats
      end

      $log.info("Importing Classification: Category: name=[#{classification["name"]}]")

      entries = classification.delete("entries")
      cat = self.create(classification)
      stats["categories"] += 1
      entries.each do |e|
        stat, e = self.import_from_hash(e, cat)
        stats.each_key { |k| stats[k] += stat[k] }
      end

      return stats, cat
    else
      entry = parent.find_entry_by_name(classification["name"])
      if entry
        $log.info("Skipping Classification (already in DB): Category: name: [#{parent.name}], Entry: name=[#{classification["name"]}]")
        return stats
      end

      $log.info("Importing Classification: Category: name: [#{parent.name}], Entry: name=[#{classification["name"]}]")
      entry = self.create(classification.merge("parent_id" => parent.id))
      stats["entries"] += 1

      return stats, entry
    end
  end

  def self.import_from_yaml(fd)
    stats = { "categories" => 0, "entries" => 0 }

    input = YAML.load(fd)
    input.each do |c|
      stat, c = import_from_hash(c)
      stats.each_key { |k| stats[k] += stat[k] }
    end

    return stats
  end

  def self.seed
    MiqRegion.my_region.lock do
      YAML.load_file(FIXTURE_FILE).each do |c|
        cat = find_by_name(c[:name], my_region_number, (c[:ns] || DEFAULT_NAMESPACE))
        next if cat

        $log.info("MIQ(Classification.seed) Creating #{c[:name]}")
        add_entries_from_hash(create(c.except(:entries)), c[:entries])
      end
    end

    # Fix categories that have a nill parent_id
    where(:parent_id => nil).update_all(:parent_id => 0)
  end

  private

  def self.add_entries_from_hash(cat, entries)
    entries.each do |entry|
      ent = cat.find_entry_by_name(entry[:name])
      ent ? ent.update_attributes(entry) : cat.add_entry(entry)
    end
  end

  def validate_uniqueness_on_tag_name
    tag = find_tag
    return if tag.nil?
    cond = ["tag_id = ?", tag.id]
    unless self.new_record?
      cond[0] << " and id <> ?"
      cond << self.id
    end
    self.errors.add("name", "has already been taken") if Classification.exists?(cond)
  end

  def validate_format_of_name
    errors.add("name", "must be lowercase alphanumeric characters and underscores without spaces") unless (self.name =~ /[^a-z0-9_:]/).nil?
  end

  def self.name2tag(name, parent_id = 0, ns = DEFAULT_NAMESPACE)
    if parent_id == 0
      tag_name = File.join(ns, name)
    else
      c = Classification.find(parent_id)
      return nil if c.nil?
      tag_name = File.join(ns, c.name, name)
    end
  end

  def tag2name(tag)
    File.split(tag).last unless tag.nil?
  end

  def self.tag2human(tag)
    c, e = tag.split("/")[2..-1]

    cat = self.find_by_name(c)
    cname = cat.nil? ? c.titleize : cat.description

    ename = e.titleize
    unless cat.nil?
      ent = cat.find_entry_by_name(e)
      ename = ent.description unless ent.nil?
    end

    return "#{cname}: #{ename}"
  end

  def find_tag
    Tag.in_my_region.find_by_name(Classification.name2tag(self.name, self.parent_id, self.ns))
  end

  def save_tag
    name = Classification.name2tag(self.name, self.parent_id, self.ns)
    tag = Tag.in_my_region.find_by_name(name)
    tag ||= Tag.create(:name => name)
    self.tag_id = tag.id
  end

  def delete_all_entries
    self.entries.each {|e| e.send(:delete_tag_and_taggings)}
  end

  def delete_tag_and_taggings
    tag = Tag.in_my_region.find_by_name(Classification.name2tag(self.name, self.parent_id, self.ns))
    return if tag.nil?

    tag.taggings.delete_all
    tag.delete
  end

  def delete_tags_and_entries
    delete_all_entries    if category?
    delete_tag_and_taggings
  end

end
