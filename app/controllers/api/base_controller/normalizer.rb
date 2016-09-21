module Api
  class BaseController
    module Normalizer
      #
      # Object or Hash Normalizer
      #

      # Note: revisit merging direct and virtual normalize hash methods here once support for
      # virtual subcollections is added.

      def normalize_hash(type, obj, opts = {})
        Environment.fetch_encrypted_attribute_names(obj.class)
        attrs = normalize_select_attributes(obj, opts)
        result = {}

        href = new_href(type, obj["id"], obj["href"], opts)
        if href.present?
          result["href"] = href
          attrs -= ["href"]
        end

        attrs.each do |k|
          value =  normalize_direct(type, k, obj.kind_of?(ActiveRecord::Base) ? obj.try(k) : obj[k])
          result[k] = value unless value.nil?
        end
        result
      end

      def normalize_virtual(vtype, name, obj, options = {})
        return normalize_virtual_array(vtype, name, obj, options) if obj.kind_of?(Array) || obj.kind_of?(ActiveRecord::Relation)
        return normalize_virtual_hash(vtype, obj, options) if obj.respond_to?(:attributes) || obj.respond_to?(:keys)
        normalize_attr_byname(name, obj)
      end

      def normalize_virtual_array(vtype, name, obj, options)
        obj.collect { |item| normalize_virtual(vtype, name, item, options) }
      end

      def normalize_virtual_hash(vtype, obj, options)
        Environment.fetch_encrypted_attribute_names(obj.class)
        attrs = (obj.respond_to?(:attributes) ? obj.attributes.keys : obj.keys)
        attrs.each_with_object({}) do |k, res|
          value = normalize_virtual(vtype, k, obj[k], options)
          res[k] = value unless options[:ignore_nil] && value.nil?
        end
      end

      #
      # Let's normalize the attribute based on its name
      #
      def normalize_attr_byname(attr, value)
        return if value.nil?
        if Environment.normalized_attributes[:time].key?(attr.to_s)
          normalize_time(value)
        elsif Environment.normalized_attributes[:url].key?(attr.to_s)
          normalize_url(value)
        elsif encrypted_attribute?(attr)
          normalize_encrypted
        elsif Environment.normalized_attributes[:resource].key?(attr.to_s)
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
        svalue.match(pref) ? svalue : "#{pref}/#{svalue}"
      end

      #
      # Let's normalize an href based on type and id value
      #
      def normalize_href(type, value)
        normalize_url("#{type}/#{value}")
      end

      #
      # Let's normalize href accessible resources
      #
      def normalize_resource(value)
        value.to_s.starts_with?("/") ? "#{@req.base}#{value}" : value
      end

      #
      # Let's determine if an attribute is encrypted
      #
      def encrypted_attribute?(attr)
        Environment.normalized_attributes[:encrypted].key?(attr.to_s) || attr.to_s.include?('password')
      end

      #
      # Let's filter out encrypted attributes, i.e. passwords
      #
      def normalize_encrypted
        nil
      end

      private

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

      def normalize_direct(type, name, obj)
        return normalize_direct_array(type, name, obj) if obj.kind_of?(Array) || obj.kind_of?(ActiveRecord::Relation)
        return normalize_hash(type, obj) if obj.respond_to?(:attributes) || obj.respond_to?(:keys)
        normalize_attr_byname(name, obj)
      end

      def normalize_direct_array(type, name, obj)
        obj.collect { |item| normalize_direct(type, name, item) }
      end

      def new_href(type, current_id, current_href, opts)
        normalize_href(type, current_id) if opts[:add_href] && current_id.present? && current_href.blank?
      end
    end
  end
end
