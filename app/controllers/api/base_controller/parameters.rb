module Api
  class BaseController
    module Parameters
      def paginate_params?
        params['offset'] || params['limit']
      end

      def expand_paginate_params
        offset = params['offset']   # 0 based
        limit  = params['limit']    # i.e. page size
        [offset, limit]
      end

      def hash_fetch(hash, element, default = {})
        hash[element] || default
      end

      #
      # Returns an MiqExpression based on the filter attributes specified.
      #
      def filter_param(klass)
        return nil if params['filter'].blank?

        operators = {
          "!=" => {:default => "!=", :regex => "REGULAR EXPRESSION DOES NOT MATCH", :null => "IS NOT NULL"},
          "<=" => {:default => "<="},
          ">=" => {:default => ">="},
          "<"  => {:default => "<", :datetime => "BEFORE"},
          ">"  => {:default => ">", :datetime => "AFTER"},
          "="  => {:default => "=", :datetime => "IS", :regex => "REGULAR EXPRESSION MATCHES", :null => "IS NULL"}
        }

        and_expressions = []
        or_expressions = []

        params['filter'].select(&:present?).each do |filter|
          parsed_filter = parse_filter(filter, operators)
          *associations, attr = parsed_filter[:attr].split(".")
          if associations.size > 1
            raise BadRequestError, "Filtering of attributes with more than one association away is not supported"
          end
          unless virtual_or_physical_attribute?(target_class(klass, associations), attr)
            raise BadRequestError, "attribute #{attr} does not exist"
          end
          associations.map! { |assoc| ".#{assoc}" }
          field = "#{klass.name}#{associations.join}-#{attr}"
          target = parsed_filter[:logical_or] ? or_expressions : and_expressions
          target << {parsed_filter[:operator] => {"field" => field, "value" => parsed_filter[:value]}}
        end

        and_part = and_expressions.one? ? and_expressions.first : {"AND" => and_expressions}
        composite_expression = or_expressions.empty? ? and_part : {"OR" => [and_part, *or_expressions]}
        MiqExpression.new(composite_expression)
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

      def parse_filter(filter, operators)
        logical_or = filter.gsub!(/^or /i, '').present?
        operator, methods = operators.find { |op, _methods| filter.partition(op).second == op }

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
                        model = collection_class(@req.subcollection || @req.collection)
                        if column_type(model, filter_attr) == :datetime
                          unless methods[:datetime]
                            raise BadRequestError, "Unsupported operator for datetime: #{operator}"
                          end
                          [filter_value, methods[:datetime]]
                        else
                          [filter_value, methods[:default]]
                        end
                      end

        if filter_value =~ /%|\*/
          filter_value = "/\\A#{Regexp.escape(filter_value)}\\z/"
          filter_value.gsub!(/%|\\\*/, ".*")
        end

        {:logical_or => logical_or, :operator => method, :attr => filter_attr, :value => filter_value}
      end

      def by_tag_param
        params['by_tag']
      end

      def search_options
        params['search_options'].to_s.split(",")
      end

      def search_option?(what)
        search_options.map(&:downcase).include?(what.to_s)
      end

      def decorator_selection
        params['decorators'].to_s.split(",")
      end

      def decorator_selection_for(collection)
        decorator_selection.collect do |attr|
          /\A#{collection}\.(?<name>.*)\z/.match(attr) { |m| m[:name] }
        end.compact
      end

      def attribute_selection
        if !@req.attributes.empty? || @additional_attributes
          @req.attributes | Array(@additional_attributes) | ID_ATTRS
        else
          "all"
        end
      end

      def attribute_selection_for(collection)
        Array(attribute_selection).collect do |attr|
          /\A#{collection}\.(?<name>.*)\z/.match(attr) { |m| m[:name] }
        end.compact
      end

      def render_attr(attr)
        as = attribute_selection
        as == "all" || as.include?(attr)
      end

      #
      # Returns the ActiveRecord's option for :order
      #
      # i.e. ['attr1 [asc|desc]', 'attr2 [asc|desc]', ...]
      #
      def sort_params(klass)
        return [] if params['sort_by'].blank?

        orders = String(params['sort_order']).split(",")
        options = String(params['sort_options']).split(",")
        params['sort_by'].split(",").zip(orders).collect do |attr, order|
          if klass.attribute_method?(attr) || klass.method_defined?(attr) || attr == klass.primary_key
            sort_directive(attr, order, options)
          else
            raise BadRequestError, "#{attr} is not a valid attribute for #{klass.name}"
          end
        end.compact
      end

      def sort_directive(attr, order, options)
        sort_item = attr
        sort_item = "LOWER(#{sort_item})" if options.map(&:downcase).include?("ignore_case")
        sort_item << " ASC"  if order && order.downcase.start_with?("asc")
        sort_item << " DESC" if order && order.downcase.start_with?("desc")
        sort_item
      end
    end
  end
end
