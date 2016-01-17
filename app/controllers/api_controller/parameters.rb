class ApiController
  module Parameters
    def paginate_params?
      params['offset'] || params['limit']
    end

    def expand_paginate_params
      offset = params['offset']   # 0 based
      limit  = params['limit']    # i.e. page size
      [offset, limit]
    end

    def json_body
      @req[:body] ||= begin
        body = request.body.read if request.body
        body.blank? ? {} : JSON.parse(body)
      end
    end

    def hash_fetch(hash, element, default = {})
      hash[element] || default
    end

    #
    # Returns an Arel definition for ActiveRecord's option for where()
    # based on the filter attributes specified.
    #
    def filter_param(klass)
      return nil if params['filter'].blank?

      operators = {"!=" => {:default => :not_eq, :str => :does_not_match, :ruby => :!=},
                   "<=" => {:default => :lteq},
                   ">=" => {:default => :gteq},
                   "<"  => {:default => :lt},
                   ">"  => {:default => :gt},
                   "="  => {:default => :eq, :str => :matches, :ruby => :==}
                  }

      res_filter = nil
      ruby_filters = []

      params['filter'].select(&:present?).each do |filter|
        parsed_filter = parse_filter(filter, operators)
        if klass.column_names.include?(parsed_filter[:attr])
          arel = klass.arel_table[parsed_filter[:attr]].send(parsed_filter[:method], parsed_filter[:value])
          res_filter = if res_filter.nil?
                         arel
                       else
                         parsed_filter[:logical_or] ? res_filter.or(arel) : res_filter.and(arel)
                       end
        elsif parsed_filter[:ruby_operator].present? && klass.virtual_attribute?(parsed_filter[:attr])
          ruby_filters << lambda do |result_set|
            result_set.select do |resource|
              attr = resource.public_send("#{parsed_filter[:attr]}")
              attr.send("#{parsed_filter[:ruby_operator]}", parsed_filter[:value])
            end
          end
        else
          raise BadRequestError, "attribute #{parsed_filter[:attr]} does not exist"
        end
      end
      [res_filter, ruby_filters]
    end

    def parse_filter(filter, operators)
      logical_or = filter.gsub!(/^or /i, '').present?
      operator, methods = operators.find { |op, _methods| filter.partition(op).second == op }

      raise BadRequestError,
            "Unknown operator specified in filter #{filter}" if operator.blank?

      filter_attr, _, filter_value = filter.partition(operator)

      filter_value = filter_value.strip
      str_method   = methods[:str] || methods[:default]

      filter_value, method =
        case filter_value
        when /^'.*'$/
          [filter_value.gsub(/^'|'$/, ''), str_method]
        when /^".*"$/
          [filter_value.gsub(/^"|"$/, ''), str_method]
        when /^(NULL|nil)$/i
          [nil, methods[:default]]
        else
          [filter_value, methods[:default]]
        end

      {
        :logical_or    => logical_or,
        :method        => method,
        :attr          => filter_attr.strip,
        :value         => filter_value,
        :ruby_operator => methods[:ruby]
      }
    end

    def by_tag_param
      params['by_tag']
    end

    def expand_param
      params['expand'] && params['expand'].split(",")
    end

    def expand?(what)
      expand_param ? expand_param.include?(what.to_s) : false
    end

    def attribute_selection
      if params['attributes'] || @req[:additional_attributes]
        params['attributes'].to_s.split(",") | Array(@req[:additional_attributes]) | ID_ATTRS
      else
        "all"
      end
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
        raise BadRequestError,
              "#{attr} is not a valid attribute for #{klass.name}" if !klass.respond_to?(attr) && attr != "id"
        sort_directive(attr, order, options)
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
