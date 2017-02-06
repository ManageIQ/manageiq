module Api
  class Filter
    include CompressedIds

    OPERATORS = {
      "!=" => {:default => "!=", :regex => "REGULAR EXPRESSION DOES NOT MATCH", :null => "IS NOT NULL"},
      "<=" => {:default => "<="},
      ">=" => {:default => ">="},
      "<"  => {:default => "<", :datetime => "BEFORE"},
      ">"  => {:default => ">", :datetime => "AFTER"},
      "="  => {:default => "=", :datetime => "IS", :regex => "REGULAR EXPRESSION MATCHES", :null => "IS NULL"}
    }.freeze

    attr_reader :filters, :model

    def initialize(filters, model)
      @filters = filters
      @model = model
    end

    def parse
      and_expressions = []
      or_expressions = []

      filters.select(&:present?).each do |filter|
        parsed_filter = parse_filter(filter)
        *associations, attr = parsed_filter[:attr].split(".")
        if associations.size > 1
          raise BadRequestError, "Filtering of attributes with more than one association away is not supported"
        end
        unless virtual_or_physical_attribute?(target_class(model, associations), attr)
          raise BadRequestError, "attribute #{attr} does not exist"
        end
        associations.map! { |assoc| ".#{assoc}" }
        field = "#{model.name}#{associations.join}-#{attr}"
        target = parsed_filter[:logical_or] ? or_expressions : and_expressions
        target << {parsed_filter[:operator] => {"field" => field, "value" => parsed_filter[:value]}}
      end

      and_part = and_expressions.one? ? and_expressions.first : {"AND" => and_expressions}
      composite_expression = or_expressions.empty? ? and_part : {"OR" => [and_part, *or_expressions]}
      MiqExpression.new(composite_expression)
    end

    private

    def parse_filter(filter)
      logical_or = filter.gsub!(/^or /i, '').present?
      operator, methods = OPERATORS.find { |op, _methods| filter.partition(op).second == op }

      raise BadRequestError,
            "Unknown operator specified in filter #{filter}" if operator.blank?

      filter_attr, _, filter_value = filter.partition(operator)
      filter_attr.strip!
      filter_value.strip!
      str_method = filter_value =~ /%|\*/ && methods[:regex] || methods[:default]

      filter_value, method =
                    case filter_value
                    when /^'.*'$/
                      [filter_value.gsub(/^'|'$/, ''), str_method]
                    when /^".*"$/
                      [filter_value.gsub(/^"|"$/, ''), str_method]
                    when /^(NULL|nil)$/i
                      [nil, methods[:null] || methods[:default]]
                    else
                      if column_type(model, filter_attr) == :datetime
                        unless methods[:datetime]
                          raise BadRequestError, "Unsupported operator for datetime: #{operator}"
                        end
                        unless Time.zone.parse(filter_value)
                          raise BadRequestError, "Bad format for datetime: #{filter_value}"
                        end
                        [filter_value, methods[:datetime]]
                      else
                        [filter_value, methods[:default]]
                      end
                    end

      filter_value = from_cid(filter_value) if filter_attr =~ /[_]?id$/ && cid?(filter_value)

      if filter_value =~ /%|\*/
        filter_value = "/\\A#{Regexp.escape(filter_value)}\\z/"
        filter_value.gsub!(/%|\\\*/, ".*")
      end

      {:logical_or => logical_or, :operator => method, :attr => filter_attr, :value => filter_value}
    end

    def target_class(klass, reflections)
      if reflections.empty?
        klass
      else
        target_class(klass.reflections_with_virtual[reflections.first.to_sym].klass, reflections[1..-1])
      end
    end

    def virtual_or_physical_attribute?(klass, attribute)
      klass.attribute_method?(attribute) || klass.virtual_attribute?(attribute)
    end
  end
end
