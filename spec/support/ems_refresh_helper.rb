module Spec
  module Support
    module EmsRefreshHelper
      def serialize_inventory
        # These models don't have tables behind them
        skip_models = [MiqRegionRemote, VmdbDatabaseConnection, VmdbDatabaseLock]
        models = ApplicationRecord.subclasses - skip_models

        # Skip attributes that always change between refreshes
        skip_attrs_global   = ["created_on", "created_at", "updated_on", "updated_at"]
        skip_attrs_by_model = {
          "ExtManagementSystem" => ["last_refresh_date", "last_refresh_success_date", "last_inventory_date"],
        }

        models.each_with_object({}) do |model, inventory|
          inventory[model.name] = model.all.map do |rec|
            skip_attrs = skip_attrs_global + skip_attrs_by_model[model.name].to_a
            rec.attributes.except(*skip_attrs)
          end
        end
      end

      def assert_inventory_not_changed(before = nil, after = nil)
        if block_given?
          before ||= serialize_inventory

          yield

          after ||= serialize_inventory
        elsif before.nil? || after.nil?
          raise ArgumentError, "You must pass before and after without a block"
        end

        expect(before.keys).to match_array(after.keys)

        before.each_key do |model|
          expect(before[model].count).to eq(after[model].count), <<~SPEC_FAILURE
            #{model} count doesn't match
            expected: #{before[model].count}
            got:      #{after[model].count}
          SPEC_FAILURE

          before[model].each do |item_before|
            item_after = after[model].detect { |i| i["id"] == item_before["id"] }
            expect(item_before).to eq(item_after), <<~SPEC_FAILURE
              #{model} ID [#{item_before["id"]}]
              expected: #{item_before}
              got:      #{item_after}
            SPEC_FAILURE
          end
        end
      end

      def with_vcr(suffix = nil, &block)
        path = described_class.name.dup
        path << "::#{suffix}" if suffix

        VCR.use_cassette(path.underscore, &block)
      end
    end
  end
end
