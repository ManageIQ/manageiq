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

    def normalize_url_from_id(_type = nil, _resource_id = nil)
      return nil if _type.nil? || _resource_id.nil?
      normalize_url(_type, "#{_type}/#{_resource_id}")
    end

  end
end
