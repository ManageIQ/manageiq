module ApiHelper
  module Normalizer
    #
    # Object or Hash Normalizer
    #

    def normalize_hash(type, obj)
      attrs = (obj.respond_to?(:attributes) ? obj.attributes.keys : obj.keys)
      attrs.each_with_object({}) do |k, res|
        res[k] =
          case obj[k]
          when Hash
            normalize_hash(type, obj[k])
          when Array
            obj[k].collect do |item|
              item.kind_of?(Hash) ? normalize_hash(type, item) : item
            end
          else
            normalize_attr_byname(type, k, obj[k])
          end
      end
    end

    def normalize_virtual(vtype, name, obj, options = {})
      return normalize_virtual_array(vtype, name, obj, options) if obj.kind_of?(Array)
      return normalize_virtual_hash(vtype, obj, options) if obj.respond_to?(:attributes) || obj.respond_to?(:keys)
      normalize_attr_byname(vtype, name, obj)
    end

    def normalize_virtual_array(vtype, name, obj, options)
      obj.collect { |item| normalize_virtual(vtype, name, item, options) }
    end

    def normalize_virtual_hash(vtype, obj, options)
      attrs = (obj.respond_to?(:attributes) ? obj.attributes.keys : obj.keys)
      attrs.each_with_object({}) do |k, res|
        value = normalize_virtual(vtype, k, obj[k], options)
        res[k] = value unless options[:ignore_nil] && value.nil?
      end
    end

    #
    # Attribute Normalizer
    #
    def normalize_attr(type, attrtype, value)
      attr_normalizer = "normalize_#{attrtype}"
      respond_to?(attr_normalizer) ? send(attr_normalizer, type, value) : value
    end

    #
    # Let's normalize the attribute based on its name
    #
    def normalize_attr_byname(type, attr, value)
      return if value.nil?
      if self.class.attr_type_hash(:time).key?(attr.to_s)
        normalize_attr(type, :time, value)
      elsif self.class.attr_type_hash(:url).key?(attr.to_s)
        normalize_attr(type, :url,  value)
      elsif self.class.attr_type_hash(:id).key?(attr.to_s)
        normalize_attr(type, :id,   value)
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
    def normalize_time(_type, value)
      return Time.at(value).utc.iso8601 if value.kind_of?(Integer)

      value.respond_to?(:utc) ? value.utc.iso8601 : value
    end

    #
    # Let's normalize a URL
    #
    # Note, all URL's are baselined as per the request specifying versioning and such.
    #
    def normalize_url(_type, value)
      svalue = value.to_s
      pref   = "#{@req[:base]}#{@req[:prefix]}"
      svalue.match(pref) ? svalue : "#{pref}/#{svalue}"
    end

    #
    # Normalize Id's, <type>/<id>
    #
    def normalize_id(type, value)
      type.nil? ? value : normalize_url(type, "#{type}/#{value}")
    end
  end
end
