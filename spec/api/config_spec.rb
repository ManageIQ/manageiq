describe 'API configuration (config/api.yml)' do
  let(:api_settings) { Api::ApiConfig }

  describe 'collections' do
    let(:collection_settings) { api_settings.collections }

    describe 'identifiers' do
      let(:miq_product_features) { MiqProductFeature.seed.values.flatten.to_set }
      let(:api_feature_identifiers) do
        collection_settings.each_with_object(Set.new) do |(_, cfg), set|
          set.add(cfg[:identifier]) if cfg[:identifier]
          subcollections = Array(cfg[:subcollections]).collect { |s| "#{s}_subcollection_actions" }
          (subcollections + [:collection_actions, :resource_actions]).each do |action_type|
            next unless cfg[action_type]
            cfg[action_type].each do |_, method_cfg|
              method_cfg.each do |action_cfg|
                set.add(action_cfg[:identifier]) if action_cfg[:identifier]
              end
            end
          end
        end
      end

      it 'is not empty' do
        expect(api_feature_identifiers).not_to be_empty
      end

      it 'contains only valid miq_feature identifiers' do
        dangling = api_feature_identifiers - miq_product_features
        expect(dangling).to be_empty
      end
    end
  end
end
