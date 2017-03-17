module ArSlug
  extend ActiveSupport::Concern

  included do
    virtual_column :href_slug, :type => :string

    def href_slug
      return unless id
      collection = Api::CollectionConfig.new.name_for_subklass(self.class)
      "#{collection}/#{id}" if collection
    end
  end
end
