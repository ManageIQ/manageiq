module ToModelHash
  extend ActiveSupport::Concern

  module ClassMethods
    def to_model_hash_options
      fname = "#{self.table_name}.yaml"
      r = MiqReport.find_by_filename_and_template_type(fname, "compare").try(:attributes)
      if r.nil?
        fname = Rails.root.join("product", "compare", fname)
        r = YAML.load_file(fname) if File.exists?(fname)
      end
      r ||= {}
      to_model_hash_options_fixup(r)
    end

    protected

    # Fixes up inconsistencies in the report format, if found
    def to_model_hash_options_fixup(options)
      return nil if options.nil?

      ret = {}

      cols  = (options["cols"] || options["columns"] || [])
      cols += (options["key"]  || []).compact
      ret[:columns] = cols.uniq.sort.collect(&:to_sym) unless cols.blank?

      includes = options["include"]
      if includes
        if includes.has_key?("categories")
          includes.delete("categories")
          includes[:tags] = nil
        end

        ret[:include] = includes.each_with_object({}) do |(k, v), h|
          sub_options = to_model_hash_options_fixup(v)
          h[k.to_sym] = sub_options.blank? ? nil : sub_options
        end
      end

      ret
    end
  end

  def to_model_hash(options = nil)
    options ||= self.class.to_model_hash_options
    ActiveRecord::Associations::Preloader.new(self, to_model_hash_build_preload(options)).run
    to_model_hash_recursive(options)
  end

  def to_model_yaml(options = nil)
    to_model_hash(options).to_yaml
  end

  protected

  def to_model_hash_attrs(options)
    columns  = ((options && options[:columns]) || self.class.column_names_symbols.dup)
    columns << :id

    columns.each_with_object({:class => self.class.name}) do |c, h|
      next unless self.respond_to?(c)
      value = self.send(c)
      h[c.to_sym] = value unless value.nil?
    end
  end

  def to_model_hash_recursive(options, result = nil)
    result ||= to_model_hash_attrs(options)

    spec = (options && options[:include])

    case spec
    when Symbol, String
      if self.respond_to?(spec)
        recs = self.send(spec)
        if recs.kind_of?(ActiveRecord::Base) || (recs.kind_of?(Array) && recs.first.kind_of?(ActiveRecord::Base))
          single_rec = !recs.kind_of?(Array)
          recs = recs.to_miq_a.collect { |v| v.to_model_hash_attrs(spec) }
          recs = recs.first if single_rec
        end
        result[spec] = recs unless recs.nil?
      end
    when Array
      spec.each { |s| to_model_hash_recursive(s, result) }
    when Hash
      spec.each do |k, v|
        next unless self.respond_to?(k)
        if k == :tags
          recs = self.tags.collect { |t| Classification.tag_to_model_hash(t) }
        else
          recs = self.send(k)
          single_rec = !recs.kind_of?(Array)
          recs = recs.to_miq_a.collect { |c| c.to_model_hash_recursive(v) }
          recs = recs.first if single_rec
        end
        result[k] = recs unless recs.nil?
      end
    end

    return result
  end

  def to_model_hash_build_preload(options)
    columns  = ((options && options[:columns]) || [])
    includes = ((options && options[:include]) || {})

    result  = columns.select { |c| self.class.virtual_column?(c) }
    result += includes.collect do |k, v|
      sub_result = to_model_hash_build_preload(v)
      sub_result.blank? ? k : { k => sub_result }
    end
  end
end

module ActiveRecord
  class Base
    include ToModelHash
  end
end
