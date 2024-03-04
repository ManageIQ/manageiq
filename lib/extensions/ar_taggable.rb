module ActiveRecord
  class Base
    def self.acts_as_miq_taggable
      has_many :taggings, :as => :taggable, :dependent => :destroy
      has_many :tags, :through => :taggings
      include ActsAsTaggable
    end
  end
end

module ActsAsTaggable
  extend ActiveSupport::Concern

  # @param tags [String,Array]
  # @param separator [String] Separator used if tags is a string
  # @return array of unique tag names
  def self.split_tag_names(tags, separator)
    case tags
    when Array
      tags.flatten.compact
    when String
      tags.split(separator)
    else
      []
    end.map(&:strip).uniq
  end

  def writable_classification_tags
    tags.merge(Classification.with_writable_parents)
  end

  module ClassMethods
    # @option options :cat [String|nil] optional category for the tags
    # @option options :ns  [String|nil] optional namespace for the tags

    # @option options :any [String] list of tags that at least one is required
    # @option options :all [String] list of tags that are all required (ignored if any is provided)
    # @option options :separator delimiter for the tags provied by all and any
    def find_tagged_with(options = {})
      tag_names = ActsAsTaggable.split_tag_names(options[:any] || options[:all], options[:separator] || ' ')
      raise "No tags were passed to :any or :all options" if tag_names.empty?

      tag_ids = Tag.for_names(tag_names, Tag.get_namespace(options)).pluck(:id)
      if options[:all]
        return none if tag_ids.length != tag_names.length
        with_all_tags(tag_ids)
      else
        with_any_tags(tag_ids)
      end
    end

    def with_any_tags(tag_ids)
      taggings = Tagging.arel_table
      where(Tagging.where(taggings[:taggable_id].eq(arel_table[:id])
                                                .and(taggings[:taggable_type].eq(base_class.name))
                                                .and(taggings[:tag_id].in(tag_ids))).arel.exists)
    end

    def with_all_tags(tag_ids)
      tag_ids.inject(self) { |rel, tag_id| rel.with_any_tags([tag_id]) }
    end

    # @param list [Array<Array<String>>] list of tags
    #   the inner list holds a single category grouped together. These are treated as an IN (aka OR) clause
    #   the outer list holds multiple categories. All of these need to match and treaded as an AND clause
    #   so the end result is the AND of a bunch of OR clauses.
    #
    # find_tagged_with(:any) is used for the inner list to handle the IN (aka OR)
    # find_tagged_with(:all) is used for multiple inner lists
    def find_tags_by_grouping(list, options = {})
      options[:ns] = Tag.get_namespace(options)
      list.inject(self) { |results, tags| results.find_tagged_with(options.merge(:any => tags)) }
    end

    def tags(options = {})
      options[:taggable_type] = base_class.name
      options[:ns] = Tag.get_namespace(options)
      Tag.tags(options)
    end

    # defines an attribute that detects a certain tag namespace
    # defines has_attrs, has_attrs? and attr_tags
    def tag_attribute(attribute_name, namespace)
      plural_attribute_name = "has_#{attribute_name.to_s.pluralize}"

      virtual_attribute plural_attribute_name, :boolean, :uses => :tags, :arel => (lambda do |t|
        ta = Tag.arel_table
        tnga = Tagging.arel_table
        t.grouping(
          Arel.sql(
            Tagging.joins(:tag).select('true')
                   .where(ta[:name].matches("#{namespace}/%", nil, true))
                   .where(tnga[:taggable_type].eq(base_class.name).and(tnga[:taggable_id].eq(arel_table[:id])))
                   .limit(1).to_sql
          )
        )
      end)

      define_method("#{attribute_name}_tags") do
        Tag.filter_ns(tags, namespace)
      end

      define_method(plural_attribute_name) do
        if has_attribute?(plural_attribute_name)
          read_attribute(plural_attribute_name) || false
        else
          Tag.filter_ns(tags, namespace).any?
        end
      end

      alias_method "#{plural_attribute_name}?", plural_attribute_name
    end
  end # module SingletonMethods

  def tag_with(list, options = {})
    ns = Tag.get_namespace(options)

    Tag.transaction do
      # Remove existing tags
      tag = Tag.arel_table
      tagging = Tagging.arel_table
      Tagging.joins(:tag)
        .where(:taggable_id    => id)
        .where(:taggable_type  => self.class.base_class.name)
        .where(tagging[:tag_id].eq(tag[:id]))
        .where(tag[:name].matches("#{ns}/%"))
        .destroy_all

      # Apply new tags
      Tag.parse(list).each do |name|
        tag = Tag.where(:name => File.join(ns, name)).first_or_create
        tag.taggings.create(:taggable => self)
      end
    end
  end

  def tag_add(list, options = {})
    ns = Tag.get_namespace(options)

    # Apply new tags
    Tag.transaction do
      Tag.parse(list).each do |name|
        next if self.is_tagged_with?(name, options)
        name = File.join(ns, name)
        tag = Tag.where(:name => name).first_or_create
        tag.taggings.create(:taggable => self)
      end
    end
  end

  def tag_remove(list, options = {})
    ns = Tag.get_namespace(options)

    # Remove tags
    Tag.transaction do
      Tag.parse(list).each do |name|
        name = File.join(ns, name)
        tag = Tag.find_by(:name => name)
        next if tag.nil?
        tag.taggings.where(:taggable => self).destroy_all
      end
    end
  end

  def tagged_with(options = {})
    tagging = Tagging.arel_table
    query = Tag.includes(:taggings).references(:taggings)
    query = query.where(tagging[:taggable_type].eq(self.class.base_class.name))
    query = query.where(tagging[:taggable_id].eq(id))
    ns    = Tag.get_namespace(options)
    query = query.where(Tag.arel_table[:name].matches("#{ns}%")) if ns
    query
  end

  def is_tagged_with?(tag, options = {})
    ns = Tag.get_namespace(options)
    return is_vtagged_with?(tag, options) if  ns[0..7] == "/virtual" || tag[0..7] == "/virtual"
    # self.tagged_with(options).include?(File.join(ns ,tag))
    Array(tags).include?(File.join(ns, tag))
  end

  def is_vtagged_with?(tag, options = {})
    ns = Tag.get_namespace(options)

    subject = self
    parts = File.join(ns, tag.split("/")).split("/")[2..-1] # throw away /virtual
    object = parts.pop
    object = object.gsub(/%2f/, "/")  unless object.nil? # decode embedded slashes
    attr = parts.pop
    begin
      # resolve any intermediate relationships, throw an error if any of them return multiple results
      while parts.length > 1
        part = parts.shift
        subject = subject.send(part.to_sym)
        raise "unable to evaluate tag, '#{tag}', because it contains multi-value reference, '#{part}' that is not the last reference" if subject.kind_of?(Array)
      end
      relationship = parts.pop
      if relationship
        macro = subject.class.reflection_with_virtual(relationship.to_sym).macro
      else
        relationship = "self"
        macro = :has_one
      end
      if macro == :has_one || macro == :belongs_to
        value = subject.public_send(relationship).public_send(attr)
        return object.downcase == value.to_s.downcase
      else
        subject.send(relationship).any? { |o| o.send(attr).to_s == object }
      end
    rescue NoMethodError
      return false
    end
  end

  def is_tagged_with_grouping?(list, options = {})
    result = true
    list.each do |inner_list|
      inner_result = false
      inner_list.each do |tag|
        if self.is_tagged_with?(tag, options)
          inner_result = true
          break
        end
      end

      if inner_result == false
        result = false
        break
      end
    end
    result
  end

  def tag_list(options = {})
    Tag.list(self, options)
  end

  def perf_tags
    tag_list(:ns => '/managed').split.join("|")
  end
end
