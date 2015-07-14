class ApiController
  module Features
    include FeatureHelper
    #
    # Features Subcollection Supporting Methods
    #
    def features_query_resource(object)
      object.send("miq_product_features")
    end

    def features_assign_resource(object, _type, id = nil, data = nil)
      # If id != 0, an href was submitted instead of id or identifier. Set id key in data hash
      data['id'] = id unless id == 0

      # Handle a features array if passed in, otherwise look for a single feature id
      if data.key?('features') && data['features'].kind_of?(Array)
        new_features = get_product_features(data['features'])
      elsif data.key?('id') || data.key?('identifier')
        new_features = get_product_features(Array.wrap(data))
      else
        api_log_info("BadRequestError, Invalid feature assignment format specified.")
        raise BadRequestError, "Invalid feature assignment format specified."
      end

      existing_features = object.miq_product_features.dup.to_a

      # Find new features that already exist in the role remove from further processing
      existing_features.each do |existing_feature|
        new_features.delete_if do |new_feature|
          existing_feature['id'] == new_feature['id']
        end
      end

      existing_features.concat(new_features)

      object.update_attribute(:miq_product_features, existing_features)
      api_log_info("Modified role #{object.name}: assigned features: #{new_features.collect(&:identifier)}")
      object
    end

    def features_unassign_resource(object, _type, id = nil, data = nil)
      # If id != 0, an href was submitted instead of id or identifier. Set id key in data hash
      data['id'] = id unless id == 0

      # Handle a features array if passed in, otherwise look for a single feature id
      if data.key?('features') && data['features'].kind_of?(Array)
        removed_features = get_product_features(data['features'])
      elsif data.key?('id') || data.key?('identifier')
        removed_features = get_product_features(Array.wrap(data))
      else
        api_log_info("BadRequestError, Invalid feature un-assignment format specified.")
        raise BadRequestError, "Invalid feature un-assignment format specified."
      end

      existing_features = object.miq_product_features.dup.to_a

      removed_features.each do |removed_feature|
        existing_features.delete_if do |existing_feature|
          removed_feature['id'] == existing_feature['id']
        end
      end

      object.update_attribute(:miq_product_features, existing_features)
      api_log_info("Modified role #{object.name}: un-assigned features: #{existing_features.collect(&:identifier)}")
      object
    end
  end
end
