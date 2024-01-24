module ManageIQ::Providers
  class Inventory::Persister
    # @see test in /spec/models/manager_refresh/inventory_collection/builder_spec.rb
    class Builder
      class MissingModelClassError < StandardError; end

      class NotSubclassedError < StandardError; end

      include ::ManageIQ::Providers::Inventory::Persister::Builder::Shared

      # Default options for builder
      #   :adv_settings
      #     - values from Advanced settings (doesn't overwrite values specified in code)
      #     - @see method ManageIQ::Providers::Inventory::Persister.make_builder_settings()
      #   :shared_properties
      #     - any properties applied if missing (not explicitly specified)
      def self.default_options
        {
          :adv_settings      => {},
          :shared_properties => {},
        }
      end

      # Entry point
      # Creates builder and builds data for inventory collection
      # @param name [Symbol, Array] InventoryCollection.association value. <name> method not called when Array
      #        (optional) method with this name also used for concrete inventory collection specific properties
      # @param persister [ManageIQ::Providers::Inventory::Persister] used for "guessing" model_class
      # @param options [Hash]
      def self.prepare_data(name, persister, options = {}, &block)
        new(name, persister, default_options.merge(options)).tap do |builder|
          builder.construct_data(&block)
        end
      end

      attr_accessor :name, :parent, :persister, :properties, :inventory_object_attributes,
                    :default_values, :dependency_attributes, :options, :adv_settings, :shared_properties

      # @see prepare_data()
      def initialize(name, persister, options = self.class.default_options)
        @name = name
        @persister = persister

        @properties = {}
        @inventory_object_attributes = []
        @default_values = {}
        @dependency_attributes = {}

        @options = options
        @options[:auto_inventory_attributes] = true if @options[:auto_inventory_attributes].nil?
        @options[:without_model_class] = false if @options[:without_model_class].nil?

        @adv_settings = options[:adv_settings] # Configuration/Advanced settings in GUI
        @shared_properties = options[:shared_properties] # From persister
        @parent = options[:parent]
      end

      def manager_class
        @manager_class ||= options[:parent].class
      end

      # Builds data for InventoryCollection
      # Calls method @name (if exists) with specific properties
      # Yields for overwriting provider-specific properties
      def construct_data
        add_properties(:association => @name)
        add_properties(:parent => parent)
        add_properties(@adv_settings, :if_missing)
        add_properties(@shared_properties, :if_missing)

        send(@name.to_sym) if @name.respond_to?(:to_sym) && respond_to?(@name.to_sym)
        yield(self) if block_given?

        if @properties[:model_class].nil? && !(@options[:without_model_class])
          add_properties(:model_class => auto_model_class)
        end
      end

      # Creates InventoryCollection
      def to_inventory_collection
        if @properties[:model_class].nil? && !@options[:without_model_class]
          raise MissingModelClassError, "Missing model_class for :#{@name} (\"#{@name.to_s.classify}\" or subclass expected)."
        end

        ::InventoryRefresh::InventoryCollection.new(to_hash)
      end

      #
      # Missing method
      #   - add_some_property(value)
      # converted to:
      #   - add_properties(:some_property => value)
      #
      def method_missing(method_name, *arguments, &block)
        if method_name.to_s.starts_with?('add_')
          add_properties(
            method_name.to_s.gsub('add_', '').to_sym => arguments[0]
          )
        else
          super
        end
      end

      def respond_to_missing?(method_name, _include_private = false)
        method_name.to_s.starts_with?('add_')
      end

      # Merges @properties
      # @see InventoryRefresh::InventoryCollection.initialize for list of properties
      #
      # @param props [Hash]
      # @param mode [Symbol] :overwrite | :if_missing
      def add_properties(props = {}, mode = :overwrite)
        @properties = merge_hashes(@properties, props, mode)
      end

      # Adds inventory object attributes (part of @properties)
      def add_inventory_attributes(array)
        @inventory_object_attributes += (array || [])
      end

      # Removes specified inventory object attributes
      def remove_inventory_attributes(array)
        @inventory_object_attributes -= (array || [])
      end

      # Clears all inventory object attributes
      def clear_inventory_attributes!
        @options[:auto_inventory_attributes] = false
        @inventory_object_attributes = []
      end

      # Adds key/values to default values (InventoryCollection.default_values) (part of @properties)
      def add_default_values(params = {}, mode = :overwrite)
        @default_values = merge_hashes(@default_values, params, mode)
      end

      # Evaluates lambda blocks
      def evaluate_lambdas!
        @default_values = evaluate_lambdas_on(@default_values, persister)
        @dependency_attributes = evaluate_lambdas_on(@dependency_attributes, persister)
      end

      # Adds key/values to dependency_attributes (part of @properties)
      def add_dependency_attributes(attrs = {}, mode = :overwrite)
        @dependency_attributes = merge_hashes(@dependency_attributes, attrs, mode)
      end

      # Deletes key from dependency_attributes
      def remove_dependency_attributes(key)
        @dependency_attributes.delete(key)
      end

      # Returns whole InventoryCollection properties
      def to_hash
        add_inventory_attributes(auto_inventory_attributes) if @options[:auto_inventory_attributes]

        @properties[:inventory_object_attributes] ||= @inventory_object_attributes

        @properties[:default_values] ||= {}
        @properties[:default_values].merge!(@default_values)

        @properties[:dependency_attributes] ||= {}
        @properties[:dependency_attributes].merge!(@dependency_attributes)

        @properties
      end

      protected

      # Extends source hash with
      # - a) all keys from dest (overwrite mode)
      # - b) missing keys (missing mode)
      #
      # @param mode [Symbol] :overwrite | :if_missing
      def merge_hashes(source, dest, mode)
        return source if source.nil? || dest.nil?

        if mode == :overwrite
          source.merge(dest)
        else
          dest.merge(source)
        end
      end

      # Derives model_class from persister class and @name
      # 1) searches for class in provider
      # 2) if not found, searches class in core
      # Can be disabled by options :auto_model_class => false
      #
      # @example derives model_class from amazon
      #
      #   @manager_class = ManageIQ::Providers::Amazon::CloudManager
      #   @name = :vms
      #
      #   returns - <provider_module>::<manager_module>::<@name.classify>
      #   returns - ::ManageIQ::Providers::Amazon::CloudManager::Vm
      #
      # @example derives model_class from @name only
      #
      #   @manager_class = nil
      #   @name = :vms
      #
      #   returns ::Vm
      #
      # @return [Class | nil] when class doesn't exist, returns nil
      def auto_model_class
        class_name = "#{manager_class}::#{name.to_s.classify}"
        provider_class = class_name.safe_constantize

        # Check that safe_constantize returns our expected class_name, if not then
        # return the base class.
        #
        # safe_constantize can return different similar class (if it is able to resolve the
        # class in the hierarchy even though it isn't at the same hierarchy depth we are expecting.
        return provider_class if provider_class.to_s == class_name

        klass = "::#{name.to_s.classify}".safe_constantize
        return if klass.nil?

        if klass.sti? && with_sti?
          raise NotSubclassedError,
                "expected #{name} to be found subclassed as #{class_name}, but instead found #{klass.name}"
        end

        klass
      end

      # Enables/disables auto_model_class and exception check
      # @param skip [Boolean]
      def skip_model_class(skip = true)
        @options[:without_model_class] = skip
      end

      def skip_sti
        @options[:without_sti] = true
      end

      def with_sti
        @options[:without_sti] = false
      end

      # Inventory object attributes are derived from setters
      #
      # Can be disabled by options :auto_inventory_attributes => false
      #   - attributes can be manually set via method add_inventory_attributes()
      def auto_inventory_attributes
        return if @properties[:model_class].nil?

        (@properties[:model_class].new.methods - ApplicationRecord.methods).grep(/^\w+?=$/).collect do |setter|
          setter.to_s[0..setter.length - 2].to_sym
        end
      end

      # Enables/disables auto_inventory_attributes
      # @param skip [Boolean]
      def skip_auto_inventory_attributes(skip = true)
        @options[:auto_inventory_attributes] = !skip
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

      private

      def with_sti?
        !@options[:without_sti]
      end
    end
  end
end
