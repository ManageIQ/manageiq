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

    [columns, data_records]
  end

  private

  def get_attributes_with_options(columns)
    return {} unless columns

    attrs = {}
    columns.each { |a| attrs[a] = send(a) if self.respond_to?(a) }
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
