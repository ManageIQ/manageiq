module Api
  module Utils
    def self.build_href_slug(klass, id)
      return unless id
      collection = Api::CollectionConfig.new.name_for_subclass(klass)
      "#{collection}/#{id}" if collection
    end
  end
end
