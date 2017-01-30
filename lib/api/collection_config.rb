module Api
  class CollectionConfig
    def self.names_for_feature(product_feature_name)
      names_for_features[product_feature_name]
    end

    def self.names_for_features
      @names_for_features ||= ApiConfig.collections.each_with_object(Hash.new { |h, k| h[k] = [] }) do |(collection, cspec), result|
        ident = cspec[:identifier]
        next unless ident
        result[ident] << collection
      end
    end
    private_class_method :names_for_features

    def self.name_for_klass(resource_klass)
      ApiConfig.collections.detect { |_, spec| spec[:klass] == resource_klass.name }.try(:first)
    end

    def self.what_refers_to_feature(product_feature_name)
      referenced_identifiers[product_feature_name]
    end

    def self.collections_with_description
      ApiConfig.collections.each_with_object({}) do |(collection, cspec), result|
        result[collection] = cspec[:description] if cspec[:options].include?(:collection)
      end
    end

    def self.referenced_identifiers
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
    private_class_method :referenced_identifiers

    def initialize(config)
      @config = config
    end

    def method_missing(method_name, *args, &block)
      config.public_send(method_name, *args, &block)
    end

    def respond_to_missing?(method_name, include_private = false)
      super || config.respond_to?(method_name, include_private)
    end

    def option?(option_name)
      config.options.include?(option_name)
    end

    def collection?
      option?(:collection)
    end

    def custom_actions?
      option?(:custom_actions)
    end

    def primary?
      option?(:primary)
    end

    def show?
      option?(:show)
    end

    def show_as_collection?
      option?(:show_as_collection)
    end

    def supports_http_method?(method)
      Array(config.verbs).include?(method)
    end

    def subcollections
      Array(config.subcollections)
    end

    def subcollection?(subcollection_name)
      subcollections.include?(subcollection_name.to_sym)
    end

    def subcollection_denied?(subcollection_name)
      config.subcollections && !subcollection?(subcollection_name)
    end

    def typed_collection_actions(target)
      config["#{target}_actions".to_sym]
    end

    def typed_subcollection_actions(subcollection_name)
      config["#{subcollection_name}_subcollection_actions".to_sym]
    end

    def typed_subcollection_action(subcollection_name, method)
      typed_subcollection_actions(subcollection_name).try(:fetch_path, method.to_sym)
    end

    def klass
      config.klass.try(:constantize)
    end

    private

    attr_reader :config
  end
end
