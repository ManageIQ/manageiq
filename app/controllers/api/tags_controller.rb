module Api
  class TagsController < BaseController
    def create_resource(type, _id, data)
      assert_id_not_specified(data, type)
      category_data = data.delete("category") { {} }
      category = fetch_category(category_data)
      unless category
        category_rep = category_data.map { |k, v| "#{k} = #{v}" }.join(', ')
        raise BadRequestError, "Could not find category with data #{category_rep}"
      end
      begin
        entry = category.add_entry(data)
        raise BadRequestError, entry.errors.full_messages.join(', ') unless entry.valid?
        entry.tag
      rescue => err
        raise BadRequestError, "Could not create a new tag - #{err}"
      end
    end

    def edit_resource(type, id, data)
      klass = collection_class(type)
      tag = resource_search(id, type, klass)
      entry = Classification.find_by(:tag_id => tag.id)
      raise BadRequestError, "Failed to find tag/#{id} resource" unless entry

      if data["name"].present?
        tag.update_attribute(:name, Classification.name2tag(data["name"], entry.parent_id, TAG_NAMESPACE))
      end
      entry.update_attributes(data.except(*ID_ATTRS))
      entry.tag
    end

    def delete_resource(_type, id, _data = {})
      destroy_tag_and_classification(id)
      action_result(true, "tags id: #{id} deleting")
    rescue ActiveRecord::RecordNotFound
      raise
    rescue => err
      action_result(false, err.to_s)
    end

    private

    def fetch_category(data)
      category_id = parse_id(data, :categories)
      category_id ||= collection_class(:categories).find_by_name(data["name"]).try(:id) if data["name"]
      unless category_id
        raise BadRequestError, "Category id, href or name needs to be specified for creating a new tag resource"
      end
      Category.find_by(:id => category_id)
    end

    def destroy_tag_and_classification(tag_id)
      entry_or_tag = Classification.find_by(:tag_id => tag_id) || Tag.find(tag_id)
      entry_or_tag.destroy!
    end
  end
end
