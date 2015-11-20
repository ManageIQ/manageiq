module ReportableMixin
  extend ActiveSupport::Concern
  included do
    cattr_accessor :aar_options, :aar_columns
  end

  module ClassMethods
    def sortable?
      true
    end

    def search(count = :all, options = {})
      conditions = options.delete(:conditions)
      filter = options.delete(:filter)

      # Do normal find
      results = []
      find(count, :conditions => conditions, :include => get_include_for_find(options[:include])).each do|obj|
        if filter
          expression = self.filter.to_ruby
          expr = Condition.subst(expression, obj, inputs)
          next unless eval(expr)
        end

        entry = {:obj => obj}
        obj.search_includes(entry, options[:include]) if options[:include]
        results.push(entry)
      end

      results
    end

    # private

    def get_include_for_find(includes)
      case includes
      when Hash
        includes.each_with_object({}) do |(k, v), result|
          v[:include] = v["include"] if v["include"]
          result[k] = get_include_for_find(v[:include] || {})
        end
      when Array
        includes.each_with_object({}) do |i, result|
          result[i] = {}
        end
      else
        includes
      end
    end
  end

  def reportable_data_with_columns(columns)
    data_records = [get_attributes_with_options(columns)]
    columns = data_records.first.keys

    data_records =
      add_includes(data_records, nil) if nil
    [columns, data_records]
  end

  def reportable_data_with_columns_vague(options = {})
    data_records = [get_attributes_with_options_vague(options)]
    columns = data_records.first.keys

    data_records =
        add_includes(data_records, options[:include]) if options[:include]
    [columns, data_records]
  end

  def reportable_data(options = {})
    columns, data_records = reportable_data_with_columns_vague(options)
    self.class.aar_columns |= columns
    data_records
  end
  Vmdb::Deprecation.deprecate_methods(self, :reportable_data => :reportable_data_with_columns)

  private

  def add_includes(data_records, includes)
    include_has_options = includes.kind_of?(Hash)
    associations = include_has_options ? includes.keys : Array(includes)

    associations.each do |association|
      existing_records = data_records.dup
      data_records = []

      if include_has_options
        assoc_options = includes[association].merge(:qualify_attribute_names => association)
      else
        assoc_options = {:qualify_attribute_names => association}
      end

      if association == "categories"
        association_hash = {}
        includes["categories"][:only].each do|c|
          entries = Classification.all_cat_entries(c, self)
          descriptions = entries.map(&:description)
          association_hash["categories." + c] = descriptions unless descriptions.empty?
        end
        # join the the category data together
        max_length = association_hash.map { |_, v| v.length }.max
        association_objects = Array.new(max_length) do |idx|
          nh = {}
          association_hash.each { |k, v| nh[k] = v[idx].nil? ? v.last : v[idx] }
          OpenStruct.new("reportable_data" => [nh])
        end
      else
        # if respond_to?(:find_filtered_children)
        #   association_objects = self.find_filtered_children(association, options).first.flatten.compact
        # else
        association_objects = [send(association)].flatten.compact
        # end
      end

      existing_records.each do |existing_record|
        if association_objects.empty?
          data_records << existing_record
        else
          association_objects.each do |obj|
            association_records = obj.reportable_data(assoc_options)
            association_records.each do |assoc_record|
              data_records << existing_record.merge(assoc_record)
            end
            self.class.aar_columns |= data_records.last.keys
          end
        end
      end
    end
    data_records
  end

  def get_attributes_with_options(columns)
    options = {
        :only        => columns,
    }
    only_or_except = nil

    if options[:only]
      only_or_except = {:only => options[:only], :except => nil}
      return {} unless only_or_except
    else
      only_or_except = nil
      return {} unless only_or_except
    end

    attrs = {}
    options[:only].each { |a| attrs[a] = send(a) if self.respond_to?(a) }
    attrs = attrs.inject({}) do |h, (k, v)|
      h["#{options[:qualify_attribute_names]}.#{k}"] = v
      h
    end if options[:qualify_attribute_names]
    attrs
  end

  def get_attributes_with_options_vague(options)
    only_or_except =
        if options[:only] || options[:except]
          {:only => options[:only], :except => options[:except]}
        end
    return {} unless only_or_except

    attrs = {}
    options[:only].each { |a| attrs[a] = send(a) if self.respond_to?(a) }
    attrs = attrs.inject({}) do |h, (k, v)|
      h["#{options[:qualify_attribute_names]}.#{k}"] = v
      h
    end if options[:qualify_attribute_names]
    attrs
  end
end
