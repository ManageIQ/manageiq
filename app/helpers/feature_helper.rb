module FeatureHelper
  def get_product_features(features_ids)
    feature_klass = collection_class(:features)

    new_features = features_ids.map do |feature|
      # Look for the feature identifier field first as this will remain constant
      if feature.key?('identifier') && !feature['identifier'].nil?
        resource_search_by_criteria('identifier', feature['identifier'], feature_klass)
      else # Fallback to a feature id or href field.
        resource_search(parse_id(feature, 'features'), 'features', feature_klass)
      end
    end
    new_features.compact
  end

  def resource_search_by_criteria(criteria, search_val, klass)
    Rbac.search(
      :targets        => Array(klass.send("find_by_#{criteria}", search_val)),
      :user           => @auth_user_obj,
      :results_format => :objects
    ).first.first
  end
end
