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

  def sqlfilter_param
    params['sqlfilter']
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
  def sort_params
    return [] if params['sort_by'].blank?

    orders = String(params['sort_order']).split(",")
    params['sort_by'].split(",").zip(orders).collect do |attr, order|
      sort_item = attr
      sort_item << " ASC"  if order && order.downcase.start_with?("asc")
      sort_item << " DESC" if order && order.downcase.start_with?("desc")
      sort_item
    end.compact
  end
end
