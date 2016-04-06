module ReportableMixin
  extend ActiveSupport::Concern
  module ClassMethods
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

  def get_attributes(columns)
    columns.each_with_object({}) do |column, attrs|
      attrs[column] = send(column) if self.respond_to?(column)
    end
  end
end
