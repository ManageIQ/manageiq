module Api
  class BaseController
    module Normalizer
      #
      # Object or Hash Normalizer
      #

      def normalize_hash(type, obj, opts = {})
        Environment.fetch_encrypted_attribute_names(obj.class)
        attrs = normalize_select_attributes(obj, opts)
        result = {}

        href = new_href(type, obj["id"], obj["href"])
        if href.present?
          result["href"] = href
          attrs -= ["href"]
        end

        attrs.each do |k|
          value = normalize_attr(k, obj.kind_of?(ActiveRecord::Base) ? obj.try(k) : obj[k])
          result[k] = value unless value.nil?
        end
        result
      end

      private

      def normalize_attr(attr, value)
        return if value.nil?
        if value.kind_of?(Array) || value.kind_of?(ActiveRecord::Relation)
          normalize_array(value)
        elsif value.respond_to?(:attributes) || value.respond_to?(:keys)
          normalize_hash(attr, value)
        elsif attr == "id" || attr.to_s.ends_with?("_id")
          ApplicationRecord.compress_id(value)
        elsif Api.time_attribute?(attr)
          normalize_time(value)
        elsif Api.url_attribute?(attr)
          normalize_url(value)
        elsif Api.encrypted_attribute?(attr)
          normalize_encrypted
        elsif Api.resource_attribute?(attr)
          normalize_resource(value)
        else
          value
        end
      end

      #
      # Timetamps should all be in the XmlSchema form, an ISO 8601
      # UTC time representation as follows: 2014-01-30T18:57:55Z
      #
      # Function takes either a Time string or Seconds since Epoch
      #
      def normalize_time(value)
        return Time.at(value).utc.iso8601 if value.kind_of?(Integer)

        value.respond_to?(:utc) ? value.utc.iso8601 : value
      end

      #
      # Let's normalize a URL
      #
      # Note, all URL's are baselined as per the request specifying versioning and such.
      #
      def normalize_url(value)
        svalue = value.to_s
        pref   = @req.api_prefix
        suffix = @req.api_suffix
        svalue.match(pref) ? svalue : "#{pref}/#{svalue}#{suffix}"
      end

      #
      # Let's normalize an href based on type and id value
      #
      def normalize_href(type, value)
        type.to_s == @req.subcollection ? subcollection_href(type, value) : collection_href(type, value)
      end

      def subcollection_href(type, value)
        normalize_url("#{@req.collection}/#{@req.c_id}/#{type}/#{value}")
      end

      def collection_href(type, value)
        normalize_url("#{type}/#{value}")
      end

      #
      # Let's normalize href accessible resources
      #
      def normalize_resource(value)
        value.to_s.starts_with?("/") ? "#{@req.base}#{value}" : value
      end

      #
      # Let's filter out encrypted attributes, i.e. passwords
      #
      def normalize_encrypted
        nil
      end

      def normalize_select_attributes(obj, opts)
        if opts[:render_attributes].present?
          opts[:render_attributes]
        elsif obj.respond_to?(:attributes) && obj.class.respond_to?(:virtual_attribute_names)
          obj.attributes.keys - obj.class.virtual_attribute_names
        elsif obj.respond_to?(:attributes)
          obj.attributes.keys
        else
          obj.keys
        end
      end

      def normalize_array(obj)
        obj.collect { |item| normalize_attr(@req.subcollection || @req.collection, item) }
      end

      def new_href(type, current_id, current_href)
        normalize_href(type, current_id) if current_id.present? && current_href.blank?
      end
    end
  end
end
