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

      def create_vm_attributes_hash(vm_attrs, vm)
        vm_attrs.each_with_object({}) do |attr, hash|
          hash[attr] = vm.public_send(attr.to_sym) if vm.respond_to?(attr.to_sym)
        end.compact
      end

      def create_vm_decorators_hash(vm_decorators, vm)
        vm_decorators.each_with_object({}) do |name, hash|
          hash[name] = vm.decorate.public_send(name.to_sym) if vm.decorate.respond_to?(name.to_sym)
        end.compact
      end
    end
  end
end
