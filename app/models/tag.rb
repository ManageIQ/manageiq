class Tag < ApplicationRecord
  has_many :taggings, :dependent => :destroy
  has_one :classification
  virtual_has_one :category,       :class_name => "Classification"
  virtual_has_one :categorization, :class_name => "Hash"

  has_many :container_label_tag_mappings

  before_destroy :remove_from_managed_filters

  def self.list(taggable, options = {})
    ns = Tag.get_namespace(options)
    return vtag_list(options) if  ns[0..7] == "/virtual"
    Tag.filter_ns(taggable.tags, ns).join(" ")
  end

  def self.vtag_list(taggable, options = {})
    ns = Tag.get_namespace(options)

    predicate = ns.split("/")[2..-1] # throw away /virtual

    # p "ns: [#{ns}]"
    # p "predicate: [#{predicate.inspect}]"

    begin
      predicate.inject(taggable) do |target, method|
        target.public_send method
      end
    rescue NoMethodError
      return ""
    end
  end

  def self.to_tag(name, options = {})
    File.join(Tag.get_namespace(options), name)
  end

  def self.tags(options = {})
    query = Tag.includes(:taggings)
    query = query.where(Tagging.arel_table[:taggable_type].eq options[:taggable_type])
    query = query.where(Tag.arel_table[:name].matches "#{options[:ns]}%") if options[:ns]
    Tag.filter_ns(query, options[:ns])
  end

  def self.all_tags(options = {})
    query = Tag.scoped
    ns    = Tag.get_namespace(options)
    query = query.where(Tag.arel_table[:name].matches "#{ns}%") unless ns.blank?
    Tag.filter_ns(query, ns)
  end

  def self.tag_count(olist, name, options = {})
    ns  = Tag.get_namespace(options)
    tag = find_by_name(File.join(ns, name))
    return 0 if tag.nil?

    if olist.kind_of?(MIQ_Report) # support for ruport
      klass        = olist.db
      taggable_ids = olist.table.data.collect { |o| o.data["id"].to_i }
    else
      klass        = olist[0].class # assumes all objects in list are of the same class
      taggable_ids = olist.collect { |o| o.id.to_i }
    end

    Tagging.where(:tag_id        => tag.id,
                  :taggable_id   => taggable_ids,
                  :taggable_type => klass.base_class.name).count
  end

  def self.parse(list)
    unless list.kind_of? Array
      tag_names = []

      # don't mangle the caller's copy
      list = list.dup

      # first, pull out the quoted tags
      list.gsub!(/\"(.*?)\"\s*/) { tag_names << $1; "" }

      # then, replace all commas with a space
      list.tr!(',', " ")

      # then, get whatever's left
      tag_names.concat list.split(/\s/)

      # strip whitespace from the names
      tag_names = tag_names.map(&:strip)

      # delete any blank tag names
      tag_names = tag_names.delete_if(&:empty?)

      return tag_names.uniq
    else
      tag_names = list.collect { |tag| tag.nil? ? nil : tag.to_s }
      return tag_names.compact
    end
  end

  # @option options :ns [String, nil]
  # @option options :cat [String, nil] optional category to add to the end (with a slash)
  # @return [String] downcases namespace or category
  def self.get_namespace(options)
    ns = options.fetch(:ns, '/user')
    ns = "" if [:none, "none", "*", nil].include?(ns)
    ns += "/" + options[:cat] if options[:cat]
    ns.include?(CustomAttributeMixin::CUSTOM_ATTRIBUTES_PREFIX) ? ns : ns.downcase
  end

  def self.filter_ns(tags, ns)
    if ns.nil?
      tags = tags.to_a    if tags.kind_of?(ActiveRecord::Relation)
      tags = tags.compact if tags.respond_to?(:compact)
      return tags
    end

    list = []
    tags.collect do |tag|
      next unless tag.name =~ %r{^#{ns}/(.*)$}i
      name = $1.include?(" ") ? "'#{$1}'" : $1
      list.push(name) unless name.blank?
    end
    list
  end

  # @param tag_names [Array<String>] list of non namespaced tags
  def self.for_names(tag_names, ns)
    fq_tag_names = tag_names.collect { |tag_name| File.join(ns, tag_name) }
    where(:name => fq_tag_names)
  end

  def self.find_by_classification_name(name, region_id = Classification.my_region_number,
                                       ns = Classification::DEFAULT_NAMESPACE, parent_id = 0)
    in_region(region_id).find_by_name(Classification.name2tag(name, parent_id, ns))
  end

  def self.find_or_create_by_classification_name(name, region_id = Classification.my_region_number,
                                                 ns = Classification::DEFAULT_NAMESPACE, parent_id = 0)
    tag_name = Classification.name2tag(name, parent_id, ns)
    in_region(region_id).find_by_name(tag_name) || create(:name => tag_name)
  end

  def ==(comparison_object)
    super || name.downcase == comparison_object.to_s.downcase
  end

  def category
    @category ||= Classification.find_by_name(name_path.split('/').first, nil)
  end

  def show
    category.try(:show)
  end

  def categorization
    @categorization ||=
      if !show
        {}
      else
        {
          "name"         => classification.name,
          "description"  => classification.description,
          "category"     => {"name" => category.name, "description" => category.description},
          "display_name" => "#{category.description}: #{classification.description}"
        }
      end
  end

  private

  def remove_from_managed_filters
    Entitlement.remove_tag_from_all_managed_filters(name)
  end

  def name_path
    @name_path ||= name.sub(%r{^/[^/]*/}, "")
  end
end
