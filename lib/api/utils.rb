module Api
  module Utils
    def self.build_href_slug(klass, id)
      return unless id
      collection = Api::CollectionConfig.new.name_for_subclass(klass)
      "#{collection}/#{ApplicationRecord.compress_id(id)}" if collection
    end

    def self.resource_search_by_href_slug(href_slug, user = User.current_user)
      return unless href_slug

      collection, id = href_slug.split('/')
      collection_config = Api::CollectionConfig.new if collection

      raise _("Invalid href_slug %{href_slug} specified") % {:href_slug => href_slug} unless collection && id && collection_config.collection?(collection)
      raise _("User must be defined") unless user

      klass = collection_config.klass(collection)
      Rbac.filtered_object(klass.find(ApplicationRecord.uncompress_id(id)), :user => user, :class => klass)
    end
  end
end
