module FeatureHelper
  def get_product_features(features_hash)
    feature_klass = collection_class(:features)

    new_features = []
    features_hash.each do |feature|
      # Look for the feature identifier field first as this will remain constant
      if feature.key?('identifier') && !feature['identifier'].nil?
        new_features.push(resource_search_by_criteria('identifier', feature['identifier'], feature_klass))
      else # Fallback to a feature id or href field.
        new_features.push(resource_search(parse_id(feature, 'features'), 'features', feature_klass))
      end
    end
    new_features.compact
  end

  def resource_search_by_criteria(criteria, search_val, klass)
    search_method = "find_by_#{criteria}"
    options = {
      :targets        => Array(klass.send(search_method, search_val)),
      :userid         => @auth_user,
      :results_format => :objects
    }
    Rbac.search(options).first.first
  end
end
