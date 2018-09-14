module ManageIQ::Providers
  class Inventory::Persister
    # @see test in /spec/models/manager_refresh/inventory_collection/builder_spec.rb
    class Builder < ::InventoryRefresh::InventoryCollection::Builder
      require_nested :AutomationManager
      require_nested :CloudManager
      require_nested :InfraManager
      require_nested :NetworkManager
      require_nested :PhysicalInfraManager
      require_nested :StorageManager
      require_nested :PersisterHelper

      include ::ManageIQ::Providers::Inventory::Persister::Builder::Shared

      def self.default_options
        super.merge(:adv_settings => {})
      end

      # @see prepare_data()
      def initialize(name, persister_class, options = self.class.default_options)
        super
        @adv_settings = options[:adv_settings] # Configuration/Advanced settings in GUI
      end

      # Builds data for InventoryCollection
      # Calls method @name (if exists) with specific properties
      # Yields for overwriting provider-specific properties
      def construct_data
        add_properties(@adv_settings, :if_missing)
        super
      end

      # Evaluates lambda blocks
      def evaluate_lambdas!(persister)
        @default_values = evaluate_lambdas_on(@default_values, persister)
        @dependency_attributes = evaluate_lambdas_on(@dependency_attributes, persister)
      end

      protected

      # Derives model_class from persister class and @name
      # 1) searches for class in provider
      # 2) if not found, searches class in core
      # Can be disabled by options :without_model_class => true
      #
      # @example derives model_class from amazon
      #
      #   @persister_class = ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager
      #   @name = :vms
      #
      #   returns - <provider_module>::<manager_module>::<@name.classify>
      #   returns - ::ManageIQ::Providers::Amazon::CloudManager::Vm
      #
      # @example derives model_class from @name only
      #
      #   @persister_class = ManageIQ::Providers::Inventory::Persister
      #   @name = :vms
      #
      #   returns ::Vm
      #
      # @return [Class | nil] when class doesn't exist, returns nil
      def auto_model_class
        model_class = begin
          # a) Provider specific class
          provider_module = ManageIQ::Providers::Inflector.provider_module(@persister_class).name
          manager_module = self.class.name.split('::').last

          class_name = "#{provider_module}::#{manager_module}::#{@name.to_s.classify}"

          inferred_class = class_name.safe_constantize

          # safe_constantize can return different similar class ( some Rails auto-magic :/ )
          if inferred_class.to_s == class_name
            inferred_class
          end
        rescue ::ManageIQ::Providers::Inflector::ObjectNotNamespacedError
          nil
        end

        if model_class
          model_class
        else
          super
        end
      end

      def ar_base_class
        ApplicationRecord
      end

      # Evaluates lambda blocks in @default_values and @dependency_attributes
      # @param values [Hash]
      # @param persister [ManageIQ::Providers::Inventory::Persister]
      def evaluate_lambdas_on(values, persister)
        values&.transform_values do |value|
          if value.respond_to?(:call)
            value.call(persister)
          else
            value
          end
        end
      end
    end
  end
end
