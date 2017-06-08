module Api
  module Subcollections
    module Tags
      def assign_tags_resource(type, id, data)
        resource = resource_search(id, type, collection_class(type))
        data['tags'].collect do |tag|
          tags_assign_resource(resource, type, tag['id'], tag)
        end
      rescue => err
        action_result(false, err.to_s)
      end

      def unassign_tags_resource(type, id, data)
        resource = resource_search(id, type, collection_class(type))
        data['tags'].collect do |tag|
          tags_unassign_resource(resource, type, tag['id'], tag)
        end
      rescue => err
        action_result(false, err.to_s)
      end

      def tags_query_resource(object)
        object ? object.tags.where(Tag.arel_table[:name].matches "#{Api::BaseController::TAG_NAMESPACE}%") : {}
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
        raise BadRequestError, entry.errors.full_messages.join(', ') unless entry.valid?
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

      private

      def destroy_tag_and_classification(tag_id)
        entry_or_tag = Classification.find_by(:tag_id => tag_id) || Tag.find(tag_id)
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
        add_parent_href_to_result(result) unless tag_spec[:href]
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
        tag  = if href && href.match(%r{^.*/tags/#{BaseController::CID_OR_ID_MATCHER}$})
                 klass = collection_class(:tags)
                 klass.find(from_cid(href.split('/').last))
               end
        tag.present? ? tag_path_to_spec(tag.name).merge(:id => tag.id) : {}
      end

      def tag_path_to_spec(path)
        tag_path = (path[0..7] == Api::BaseController::TAG_NAMESPACE) ? path[8..-1] : path
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
        action_result(success, desc, :parent_id => ci.id)
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
        action_result(success, desc, :parent_id => ci.id)
      rescue => err
        action_result(false, err.to_s)
      end

      def ci_is_tagged_with?(ci, tag_spec)
        ci.is_tagged_with?(tag_spec[:name], :ns => "#{Api::BaseController::TAG_NAMESPACE}/#{tag_spec[:category]}")
      end
    end
  end
end
