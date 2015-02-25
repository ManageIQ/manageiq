module ApiHelper
  #
  # Api Support
  #
  include_concern 'Logger'
  include_concern 'ErrorHandler'
  include_concern 'Normalizer'
  include_concern 'Renderer'
  include_concern 'Results'

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
      body =
        if request.body
          request.body.read.tap do |b|
            api_log_debug("\n#{@name} Request Body:\n#{b}") if api_log_debug? && b
          end
        end
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

    operators = {"!=" => {:default => :not_eq, :str => :does_not_match},
                 "<=" => {:default => :lteq},
                 ">=" => {:default => :gteq},
                 "<"  => {:default => :lt},
                 ">"  => {:default => :gt},
                 "="  => {:default => :eq, :str => :matches}
                }

    res_filter = nil
    params['filter'].select(&:present?).each do |filter|
      parsed_filter = parse_filter(filter, operators)

      arel = klass.arel_table[parsed_filter[:attr]].send(parsed_filter[:method], parsed_filter[:value])
      res_filter = if res_filter.nil?
                     arel
                   else
                     parsed_filter[:logical_or] ? res_filter.or(arel) : res_filter.and(arel)
                   end
    end
    res_filter
  end

  def parse_filter(filter, operators)
    logical_or = filter.gsub!(/^or /i, '').present?
    operator, methods  = operators.select { |op, _methods| filter.partition(op).second == op }.first

    raise ApiController::BadRequestError,
          "Unknown operator specified in filter #{filter}" if operator.blank?

    filter_attr, _, filter_value = filter.partition(operator)

    filter_value = filter_value.strip
    str_method   = methods[:str] || methods[:default]

    if filter_value.match(/^'.*'$/)
      filter_value, method = filter_value.gsub(/^'|'$/, ''), str_method
    elsif filter_value.match(/^".*"$/)
      filter_value, method = filter_value.gsub(/^"|"$/, ''), str_method
    else
      method = methods[:default]
    end

    {:logical_or => logical_or, :method => method, :attr => filter_attr.strip, :value => filter_value}
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
    params['attributes'] ? params['attributes'].split(",") | ApiController::ID_ATTRS : "all"
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
    params['sort_by'].split(",").zip(orders).collect do |attr, order|
      raise ApiController::BadRequestError,
            "#{attr} is not a valid attribute for #{klass.name}" if !klass.respond_to?(attr) && attr != "id"
      sort_directive(attr, order)
    end.compact
  end

  def sort_directive(attr, order)
    sort_item = attr
    sort_item << " ASC"  if order && order.downcase.start_with?("asc")
    sort_item << " DESC" if order && order.downcase.start_with?("desc")
    sort_item
  end
end
