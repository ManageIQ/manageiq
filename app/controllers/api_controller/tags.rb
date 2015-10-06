class ApiController
  module Tags
    #
    # Tags Subcollection Supporting Methods
    #
    # Signature <<subcollection>>_<<action>>_resource(object, type, id, data)
    #

    def tags_query_resource(object)
      object ? object.tags.where(Tag.arel_table[:name].matches "#{TAG_NAMESPACE}%") : {}
    end

    def tags_assign_resource(object, _type, id = nil, data = nil)
      tag_spec = tag_specified(id, data)
      tag_subcollection_action(tag_spec) do
        api_log_info("Assigning #{tag_ident(tag_spec)}")
        ci_set_tag(object, tag_spec)
      end
    end

    def tags_unassign_resource(object, _type, id = nil, data = nil)
      tag_spec = tag_specified(id, data)
      tag_subcollection_action(tag_spec) do
        api_log_info("Unassigning #{tag_ident(tag_spec)}")
        ci_unset_tag(object, tag_spec)
      end
    end

    def tags_create_resource(parent, _type, _id, data)
      entry = parent.add_entry(data)
      raise_failed_to_add_resource_error(:tag, entry) unless entry.valid?
      entry.tag
    end

    def create_resource_tags(_type, _id, data)
      raise_resource_id_or_href_specified_error(:tag) if data.key?("id") || data.key?("href")
      category_data = data.delete("category") { {} }
      category = fetch_category(category_data)
      raise_could_not_find_resource_error(:category, category_data) unless category
      entry = category.add_entry(data)
      raise_failed_to_add_resource_error(:tag, entry) unless entry.valid?
      entry.tag
    end

    def edit_resource_tags(type, id, data)
      klass = collection_class(type)
      tag = resource_search(id, type, klass)
      entry = Classification.find_by_tag_id(tag.id)
      raise_could_not_find_resource_by_id_error(:tag, id) unless entry

      if data["name"].present?
        tag.update_attribute(:name, Classification.name2tag(data["name"], entry.parent_id, TAG_NAMESPACE))
      end
      entry.update_attributes(data.except(*ID_ATTRS))
      entry.tag
    end

    private

    def fetch_category(data)
      if data.key?("id")
        category_id = data["id"]
      elsif data.key?("href")
        _, category_id = parse_href(data["href"])
      else
        raise_parent_id_or_href_not_specified_error(:category, :tag)
      end
      Category.find_by_id(category_id)
    end

    def tag_ident(tag_spec)
      "Tag: category:'#{tag_spec[:category]}' name:'#{tag_spec[:name]}'"
    end

    def tag_subcollection_action(tag_spec)
      if tag_spec[:category] && tag_spec[:name]
        result = yield if block_given?
      else
        result = action_result(false, "Missing tag category or name")
      end

      add_parent_href_to_result(result)
      add_tag_to_result(result, tag_spec)
      log_result(result)
      result
    end

    def tag_specified(id, data)
      if id.to_i > 0
        klass  = collection_class(:tags)
        tagobj = klass.find(id)
        return tag_path_to_spec(tagobj.name).merge(:id => tagobj.id)
      end

      parse_tag(data)
    end

    def parse_tag(data)
      return {} if data.blank?

      category = data["category"]
      name     = data["name"]
      return {:category => category, :name => name} if category && name
      return tag_path_to_spec(name) if name && name[0] == '/'

      parse_tag_from_href(data)
    end

    def parse_tag_from_href(data)
      href = data["href"]
      tag  = if href && href.match(%r{^.*/tags/[0-9]+$})
               klass = collection_class(:tags)
               klass.find(href.split('/').last)
             end
      tag.present? ? tag_path_to_spec(tag.name).merge(:id => tag.id) : {}
    end

    def tag_path_to_spec(path)
      tag_path = (path[0..7] == TAG_NAMESPACE) ? path[8..-1] : path
      parts    = tag_path.split('/')
      {:category => parts[1], :name => parts[2]}
    end

    def ci_set_tag(ci, tag_spec)
      if ci_is_tagged_with?(ci, tag_spec)
        desc = "Already tagged with #{tag_ident(tag_spec)}"
        success = true
      else
        desc = "Assigning #{tag_ident(tag_spec)}"
        Classification.classify(ci, tag_spec[:category], tag_spec[:name])
        success = ci_is_tagged_with?(ci, tag_spec)
      end
      action_result(success, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def ci_unset_tag(ci, tag_spec)
      if ci_is_tagged_with?(ci, tag_spec)
        desc = "Unassigning #{tag_ident(tag_spec)}"
        Classification.unclassify(ci, tag_spec[:category], tag_spec[:name])
        success = !ci_is_tagged_with?(ci, tag_spec)
      else
        desc = "Not tagged with #{tag_ident(tag_spec)}"
        success = true
      end
      action_result(success, desc)
    rescue => err
      action_result(false, err.to_s)
    end

    def ci_is_tagged_with?(ci, tag_spec)
      ci.is_tagged_with?(tag_spec[:name], :ns => "#{TAG_NAMESPACE}/#{tag_spec[:category]}")
    end
  end
end
