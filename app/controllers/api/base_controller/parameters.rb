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
        Filter.new(params["filter"], klass, @req).parse
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
          if klass.virtual_attribute?(attr) && !klass.attribute_supported_by_sql?(attr)
            raise BadRequestError, "#{klass.name} cannot be sorted by #{attr}"
          elsif klass.attribute_supported_by_sql?(attr)
            sort_directive(klass, attr, order, options)
          else
            raise BadRequestError, "#{attr} is not a valid attribute for #{klass.name}"
          end
        end.compact
      end

      def sort_directive(klass, attr, order, options)
        arel = klass.arel_attribute(attr)
        if order
          arel = arel.lower if options.map(&:downcase).include?("ignore_case")
          arel = arel.desc if order.downcase == "desc"
        end
        arel
      end
    end
  end
end
