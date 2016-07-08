class ApiController
  class CollectionConfig < Config::Options
    def custom_actions?(collection_name)
      cspec = self[collection_name.to_sym]
      cspec && cspec[:options].include?(:custom_actions)
    end

    def show_as_collection?(collection_name)
      self[collection_name.to_sym][:options].include?(:show_as_collection)
    end

    def names_for_feature(product_feature_name)
      names_for_features[product_feature_name]
    end

    def klass(collection_name)
      c(collection_name)[:klass].constantize
    end

    def name_for_klass(resource_klass)
      detect do |_, spec|
        spec[:klass] && spec[:klass].constantize == resource_klass
      end.try(:first)
    end

    private

    def names_for_features
      @names_for_features ||= each_with_object(Hash.new { |h, k| h[k] = [] }) do |(collection, cspec), result|
        ident = cspec[:identifier]
        next unless ident
        result[ident] << collection
      end
    end
  end
end
