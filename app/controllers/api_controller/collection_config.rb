class ApiController
  class CollectionConfig < Config::Options
    def custom_actions?(collection_name)
      cspec = self[collection_name.to_sym]
      cspec && cspec[:options].include?(:custom_actions)
    end

    def show_as_collection?(collection_name)
      self[collection_name.to_sym][:options].include?(:show_as_collection)
    end

    def subcollection?(collection_name, subcollection_name)
      Array(self[collection_name.to_sym][:subcollections]).include?(subcollection_name.to_sym)
    end

    def subcollection_denied?(collection_name, subcollection_name)
      self[collection_name.to_sym][:subcollections] && !self[collection_name.to_sym][:subcollections].include?(subcollection_name.to_sym)
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

    def what_refers_to_feature(product_feature_name)
      referenced_identifiers[product_feature_name]
    end

    private

    def names_for_features
      @names_for_features ||= each_with_object(Hash.new { |h, k| h[k] = [] }) do |(collection, cspec), result|
        ident = cspec[:identifier]
        next unless ident
        result[ident] << collection
      end
    end

    def referenced_identifiers
      @referenced_identifiers ||= each_with_object({}) do |(collection, cspec), result|
        next unless cspec[:collection_actions].present?
        cspec[:collection_actions].each do |method, action_definitions|
          next unless action_definitions.present?
          action_definitions.each do |action|
            identifier = action[:identifier]
            next if action[:disabled] || result.key?(identifier)
            result[identifier] = [collection, method, action]
          end
        end
      end
    end
  end
end
