module ArHrefSlug
  extend ActiveSupport::Concern

  included do
    virtual_column :href_slug, :type => :string

    def href_slug
      Api::Utils.build_href_slug(self.class, id)
    end
  end
end
