class ApiController
  module CustomAttributes
    #
    # Custom Attributes Supporting Methods
    #
    def custom_attributes_query_resource(object)
      object.custom_attributes
    end

    def custom_attributes_add_resource(object, _type, _id, data = nil)
      add_custom_attribute(object, data)
    end

    def custom_attributes_edit_resource(object, _type, id = nil, data = nil)
      ca = find_custom_attribute(object, id, data)
      edit_custom_attribute(object, ca, data)
    end

    def custom_attributes_delete_resource(object, _type, id = nil, data = nil)
      ca = find_custom_attribute(object, id, data)
      delete_custom_attribute(object, ca)
    end

    private

    def add_custom_attribute(object, data)
      ca = find_custom_attribute_by_data(object, data)
      if ca.present?
        update_custom_attributes(ca, data)
      else
        ca = new_custom_attribute(data)
        object.custom_attributes << ca
      end
      update_custom_field(object, ca)
      ca
    end

    def edit_custom_attribute(object, ca, data)
      return if ca.blank?
      update_custom_attributes(ca, data)
      update_custom_field(object, ca)
      ca
    end

    def delete_custom_attribute(object, ca)
      return if ca.blank?
      object.set_custom_field(ca.name, '') if ca.stored_on_provider?
      ca.delete
      ca
    end

    def update_custom_attributes(ca, data)
      ca.update_attributes(data.slice("name", "value", "section"))
    end

    def update_custom_field(object, ca)
      object.set_custom_field(ca.name.to_s, ca.value.to_s) if ca.stored_on_provider?
    end

    def find_custom_attribute(object, id, data)
      (id.present? && id > 0) ? object.custom_attributes.find(id) : find_custom_attribute_by_data(object, data)
    end

    def find_custom_attribute_by_data(object, data)
      object.custom_attributes.detect do |ca|
        ca.section.to_s == data["section"].to_s && ca.name.downcase == data["name"].downcase
      end
    end

    def new_custom_attribute(data)
      name = data["name"].to_s.strip
      raise BadRequestError, "Must specify a name for a custom attribute to be added" if name.blank?
      CustomAttribute.new(:name    => name,
                          :value   => data["value"],
                          :source  => data["source"].blank? ? "EVM" : data["source"],
                          :section => data["section"]
      )
    end
  end
end
