class Tag < ActiveRecord::Base
  has_many :taggings, :dependent => :destroy
  has_one :classification
  virtual_has_one :category,       :class_name => "Classification"
  virtual_has_one :categorization, :class_name => "Hash"

  def self.to_tag(name, options = {})
    File.join(Tag.get_namespace(options), name)
  end

  def self.add(list, options = {})
    ns = Tag.get_namespace(options)
    Tag.parse(list).each do |name|
      Tag.find_or_create_by_name(File.join(ns ,name))
    end
  end

  def self.remove(list, options = {})
    ns = Tag.get_namespace(options)
    Tag.parse(list).each do |name|
      tag = Tag.find_by_name(File.join(ns ,name))
      tag.destroy unless tag.nil?
    end
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

    if olist.is_a?(MIQ_Report) # support for ruport
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

      # first, pull out the quoted tags
      list.gsub!(/\"(.*?)\"\s*/ ) { tag_names << $1; "" }

      # then, replace all commas with a space
      list.gsub!(/,/, " ")

      # then, get whatever's left
      tag_names.concat list.split(/\s/)

      # strip whitespace from the names
      tag_names = tag_names.map(&:strip)

      # delete any blank tag names
      tag_names = tag_names.delete_if(&:empty?)

      return tag_names.uniq
    else
      tag_names = list.collect {|tag| tag.nil? ? nil : tag.to_s}
      return tag_names.compact
    end
  end

  def self.get_namespace(options)
    options = {:ns => '/user'}.merge(options)
    ns = options[:ns]
    ns = "" if [:none, "none", "*", nil].include?(options[:ns])
    options[:cat].nil? ? ns.downcase : [ns, options[:cat]].join("/").downcase
  end

  def self.filter_ns(tags, ns)
    if ns.nil?
      tags = tags.all     if tags.kind_of?(ActiveRecord::Relation)
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

  def name_path
    @name_path ||= name.sub(%r{^/[^/]*/}, "")
  end
end
