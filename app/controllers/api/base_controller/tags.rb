module Api
  class BaseController
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
        raise BadRequestError, "#{entry.errors.full_messages.join(', ')}" unless entry.valid?
        entry.tag
      rescue => err
        raise BadRequestError, "Could not create a new tag - #{err}"
      end

      def tags_delete_resource(_parent, _type, id, data)
        id ||= parse_id(data, :tags) || parse_by_attr(data, :tags, %w(name))
        raise BadRequestError, "Tag id, href or name needs to be specified for deleting a tag resource" unless id
        destroy_tag_and_classification(id)
        action_result(true, "tags id: #{id} deleting")
      rescue => err
        action_result(false, err.to_s)
      end

      def create_resource_tags(type, _id, data)
        assert_id_not_specified(data, type)
        category_data = data.delete("category") { {} }
        category = fetch_category(category_data)
        unless category
          category_rep = category_data.map { |k, v| "#{k} = #{v}" }.join(', ')
          raise BadRequestError, "Could not find category with data #{category_rep}"
        end
        begin
          entry = category.add_entry(data)
          raise BadRequestError, "#{entry.errors.full_messages.join(', ')}" unless entry.valid?
          entry.tag
        rescue => err
          raise BadRequestError, "Could not create a new tag - #{err}"
        end
      end

      def edit_resource_tags(type, id, data)
        klass = collection_class(type)
        tag = resource_search(id, type, klass)
        entry = Classification.find_by_tag_id(tag.id)
        raise BadRequestError, "Failed to find tag/#{id} resource" unless entry

        if data["name"].present?
          tag.update_attribute(:name, Classification.name2tag(data["name"], entry.parent_id, TAG_NAMESPACE))
        end
        entry.update_attributes(data.except(*ID_ATTRS))
        entry.tag
      end

      def delete_resource_tags(_type, id, _data = {})
        destroy_tag_and_classification(id)
        action_result(true, "tags id: #{id} deleting")
      rescue ActiveRecord::RecordNotFound
        raise
      rescue => err
        action_result(false, err.to_s)
      end

      private

      def fetch_category(data)
        category_id = parse_id(data, :categories) || parse_by_attr(data, :categories, %w(name))
        unless category_id
          raise BadRequestError, "Category id, href or name needs to be specified for creating a new tag resource"
        end
        Category.find_by_id(category_id)
      end

      def destroy_tag_and_classification(tag_id)
        entry_or_tag = Classification.find_by_tag_id(tag_id) || Tag.find(tag_id)
        entry_or_tag.destroy!
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
        tag  = if href && href.match(%r{^.*/tags/[0-9r]+$})
                 klass = collection_class(:tags)
                 klass.find(from_cid(href.split('/').last))
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
end
