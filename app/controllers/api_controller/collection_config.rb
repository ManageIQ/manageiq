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
