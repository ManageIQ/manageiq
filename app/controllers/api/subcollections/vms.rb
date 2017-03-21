module Api
  module Subcollections
    module Vms
      def vms_query_resource(object)
        vms = object.try(:vms) || []

        vm_attrs = attribute_selection_for("vms")
        vm_decorators = decorator_selection_for("vms")

        return vms if vm_attrs.blank? && vm_decorators.blank?

        vms.collect do |vm|
          attributes_hash = create_vm_attributes_hash(vm_attrs, vm)
          decorators_hash = create_vm_decorators_hash(vm_decorators, vm)

          conflictless_hash = attributes_hash.merge(decorators_hash || {}) do |key, _, _|
            raise BadRequestError, "Requested both an attribute and a decorator of the same name: #{key}"
          end

          vm.as_json.merge(conflictless_hash)
        end
      end

      private

      def decorator_selection
        params['decorators'].to_s.split(",")
      end

      def decorator_selection_for(collection)
        decorator_selection.collect do |attr|
          /\A#{collection}\.(?<name>.*)\z/.match(attr) { |m| m[:name] }
        end.compact
      end

      def create_vm_attributes_hash(vm_attrs, vm)
        vm_attrs.each_with_object({}) do |attr, hash|
          hash[attr] = vm.public_send(attr.to_sym) if vm.respond_to?(attr.to_sym)
        end.compact
      end

      def create_vm_decorators_hash(vm_decorators, vm)
        hash = {}
        if vm_decorators.include? 'supports_console?'
          hash['supports_console?'] = vm.supports_console?
        end
        if vm_decorators.include? 'supports_cockpit?'
          hash['supports_cockpit?'] = vm.supports_launch_cockpit?
        end
        hash
      end
    end
  end
end
