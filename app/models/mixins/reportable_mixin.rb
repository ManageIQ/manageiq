module ReportableMixin
  extend ActiveSupport::Concern
  module ClassMethods
    def search(count = :all, options = {})
      filter = options.delete(:filter)

      records = find(count, :conditions => options[:conditions], :include => get_include_for_find(options[:include]))

      records = records.select do |obj|
        if filter
          expression = self.filter.to_ruby
          expr = Condition.subst(expression, obj)
          eval(expr)
        else
          true
        end
      end

      records.collect do |obj|
        entry = {:obj => obj}
        build_search_includes(obj, entry, options[:include]) if options[:include]
        entry
      end
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
