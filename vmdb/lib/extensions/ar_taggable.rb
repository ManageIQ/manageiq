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

  def self.split_tag_names(tags, separator)
    tag_names = []
    if tags.is_a?(Array)
      tag_names.push(tags)
    elsif tags.is_a?(String)
      tag_names.push((separator.is_a?(Proc) ? separator.call(tags) : tags.split(separator)))
    end
    tag_names.flatten.map { |name| name.strip }.uniq.compact
  end

  module ClassMethods
    def find_tagged_with(options = {})
      options = { :separator => ' ' }.merge(options)
      options[:ns] = Tag.get_namespace(options)

      tag_names = ActsAsTaggable.split_tag_names(options[:any] || options[:all], options[:separator])
      fq_tag_names = tag_names.collect { |tag_name| File.join(options[:ns], tag_name) }
      raise "No tags were passed to :any or :all options" if fq_tag_names.empty?

      tag_ids = Tag.where(:name => fq_tag_names).pluck(:id)

      # Bailout if not enough tags were found
      return self.none if options[:all] && tag_ids.length != fq_tag_names.length

      taggings = Tagging.arel_table
      self_arel = self.arel_table
      query = self.uniq.joins(:taggings).where(taggings[:tag_id].in tag_ids)

      if options[:all]
        grouping_cols = [taggings[:taggable_id]] + column_names.collect { |c| self_arel[c] }
        query = query.group(*grouping_cols).having(taggings[:id].count.gteq tag_names.length)
      end

      query
    end

    def find_tags_by_grouping(list, options = {})
      options[:ns] = Tag.get_namespace(options)

      # If array is flat (contains no inner arrays) we can let find_tagged_with
      # do all the work. This will be much faster.
      # Otherwise we'll need to call find_tagged_with for each inner list, prune the results
      # and honor offset and limit here.
      inner_lists = false
      list.each do |item|
        if item.is_a?(Array) && item.length > 1
          inner_lists = true
          break
        end
      end
      return find_tagged_with(options.merge(:all=>list)) unless inner_lists == true

      offset = options.delete(:offset)
      limit = options.delete(:limit)
      count = options.delete(:count)
      results = nil
      list.each do |inner_list|
        ret = find_tagged_with(options.merge(:any=>inner_list))
        if results.nil?
          results = ret
          next
        end

        results.delete_if { |obj| !ret.include?(obj) }
        break if results.empty?
      end
      if limit
        offset ||= 0
        results = results[offset..offset+limit-1]
      end
      count ? results.length : results
    end

    def tags(options = {})
      options.merge!(:taggable_type => self.base_class.name)
      options[:ns] = Tag.get_namespace(options)
      Tag.tags(options)
    end
  end # module SingletonMethods

  def tag_with(list, options = {})
    ns = Tag.get_namespace(options)

    Tag.transaction do
      # Remove existing tags
      tag = Tag.arel_table
      Tagging.joins(:tag).
                where(:taggable_id    => self.id).
                where(:taggable_type  => self.class.base_class.name).
                where(:tag_id         => tag[:id]).
                where(tag[:name].matches "#{ns}/%").
                destroy_all

      # Apply new tags
      Tag.parse(list).each do |name|
        tag = Tag.find_or_create_by_name(File.join(ns, name))
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
        tag = Tag.find_or_create_by(:name => name)
        tag.taggings.create(:taggable => self)
      end
    end
  end

  def tag_remove(list, options = {})
    # remove taggings from object
    ns = Tag.get_namespace(options)
    Tag.parse(list).each do |name|
      self.taggings.
            includes(:tag).
            where(Tag.arel_table[:name].eq File.join(ns, name)).
            destroy_all
    end
  end

  def tagged_with(options = {})
    tagging = Tagging.arel_table
    query = Tag.includes(:taggings)
    query = query.where(tagging[:taggable_type].eq self.class.base_class.name)
    query = query.where(tagging[:taggable_id].eq self.id)
    ns    = Tag.get_namespace(options)
    query = query.where(Tag.arel_table[:name].matches "#{ns}%") if ns
    query
  end

  def is_tagged_with?(tag, options = {})
    ns = Tag.get_namespace(options)
    return is_vtagged_with?(tag, options) if  ns[0..7] == "/virtual" || tag[0..7] == "/virtual"
    # self.tagged_with(options).include?(File.join(ns ,tag))
    Array(tags).include?(File.join(ns, tag))
  end

  def is_vtagged_with?(tag, options={})
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
        raise "unable to evaluate tag, '#{tag}', because it contains multi-value reference, '#{part}' that is not the last reference" if subject.is_a?(Array)
      end
      relationship = parts.pop
      unless relationship
        relationship = "self"
        macro = :has_one
      else
        macro = subject.class.reflect_on_association(relationship.to_sym).macro
      end
      if macro == :has_one || macro == :belongs_to
        value = subject.instance_eval([relationship, attr].join("."))
        return object.downcase == value.to_s.downcase
      else
        subject.send(relationship).any? { |o| o.send(attr).to_s == object }
      end
    rescue NoMethodError => err
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
    ns = Tag.get_namespace(options)
    return vtag_list(options) if  ns[0..7] == "/virtual"
    Tag.filter_ns(tags, ns).join(" ")
  end

  def vtag_list(options = {})
    ns = Tag.get_namespace(options)

    subject = "self"
    predicate = ns.split("/")[2..-1] # throw away /virtual

    # p "ns: [#{ns}]"
    # p "predicate: [#{predicate.inspect}]"

    begin
      value = eval(predicate.unshift(subject).join("."))
    rescue NoMethodError => err
      return ""
    end

    value
  end
end

