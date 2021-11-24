module ManageIQ::Providers
  class Regions
    class << self
      def regions
        from_file.merge(additional_regions).except(*disabled_regions)
      end

      def all
        regions.values
      end

      def names
        regions.keys
      end

      private

      def from_file
        # Memoize the regions file as this should not change at runtime
        @from_file ||= YAML.load_file(regions_yml).transform_values(&:freeze).freeze
      end

      def additional_regions
        Settings.dig(:ems, ems_type, :additional_regions).to_h.stringify_keys
      end

      def disabled_regions
        Settings.dig(:ems, ems_type, :disabled_regions).to_a
      end

      def ems_type
        vendor = module_parent.name.sub("ManageIQ::Providers::", "").sub("::", "_").downcase

        "ems_#{vendor}".to_sym
      end

      def regions_yml
        module_parent::Engine.root.join("config/regions.yml")
      end
    end
  end
end
