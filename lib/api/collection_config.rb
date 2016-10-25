module Api
  class CollectionConfig
    def initialize
      @cfg = ApiConfig.collections
    end

    def [](collection_name)
      @cfg[collection_name.to_sym]
    end

    def option?(collection_name, option_name)
      self[collection_name][:options].include?(option_name) if self[collection_name]
    end

    def collection?(collection_name)
      option?(collection_name, :collection)
    end

    def custom_actions?(collection_name)
      option?(collection_name, :custom_actions)
    end

    def primary?(collection_name)
      option?(collection_name, :primary)
    end

    def show?(collection_name)
      option?(collection_name, :show)
    end

    def show_as_collection?(collection_name)
      option?(collection_name, :show_as_collection)
    end

    def supports_http_method?(collection_name, method)
      Array(self[collection_name][:verbs]).include?(method)
    end

    def subcollections(collection_name)
      Array(self[collection_name][:subcollections])
    end

    def subcollection?(collection_name, subcollection_name)
      subcollections(collection_name).include?(subcollection_name.to_sym)
    end

    def subcollection_denied?(collection_name, subcollection_name)
      self[collection_name][:subcollections] &&
        !self[collection_name][:subcollections].include?(subcollection_name.to_sym)
    end

    def typed_collection_actions(collection_name, target)
      self[collection_name]["#{target}_actions".to_sym]
    end

    def typed_subcollection_actions(collection_name, subcollection_name)
      self[collection_name]["#{subcollection_name}_subcollection_actions".to_sym]
    end

    def typed_subcollection_action(collection_name, subcollection_name, method)
      typed_subcollection_actions(collection_name, subcollection_name).try(:fetch_path, method.to_sym)
    end

    def names_for_feature(product_feature_name)
      names_for_features[product_feature_name]
    end

    def klass(collection_name)
      self[collection_name][:klass].try(:constantize)
    end

    def name_for_klass(resource_klass)
      @cfg.detect { |_, spec| spec[:klass] == resource_klass.name }.try(:first)
    end

    def what_refers_to_feature(product_feature_name)
      referenced_identifiers[product_feature_name]
    end

    def collections_with_description
      @cfg.each_with_object({}) do |(collection, cspec), result|
        result[collection] = cspec[:description] if cspec[:options].include?(:collection)
      end
    end

    private

    def names_for_features
      @names_for_features ||= @cfg.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(collection, cspec), result|
        ident = cspec[:identifier]
        next unless ident
        result[ident] << collection
      end
    end

    def referenced_identifiers
      @referenced_identifiers ||= @cfg.each_with_object({}) do |(collection, cspec), result|
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
