#
# Module for saving orchestration stacks related inventory
# - orchestration_templates
# - orchestration_stacks
# - parameters_inventory
# - resources_inventory
# - outputs_inventory

module EmsRefresh
  module SaveInventoryOrchestrationStacks
    def save_orchestration_templates_inventory(_ems, hashes, _target = nil)
      # cloud_stack_template does not belong to an ems;
      # only to create new if necessary, but not to update existing template
      templates = OrchestrationTemplate.find_or_create_by_contents(hashes)
      hashes.zip(templates).each { |hash, template| hash[:id] = template.id }
    end

    def save_orchestration_stacks_inventory(ems, hashes, target = nil)
      target = ems if target.nil?

      deletes = target == ems ? :use_association : []

      hashes.each do |h|
        h[:orchestration_template_id] = h.fetch_path(:orchestration_template, :id)
        h[:cloud_tenant_id]           = h.fetch_path(:cloud_tenant, :id)
      end

      stacks = save_inventory_multi(ems.orchestration_stacks,
                                    hashes,
                                    deletes,
                                    [:ems_ref],
                                    [:parameters, :outputs, :resources],
                                    [:parent, :orchestration_template, :cloud_tenant])

      store_ids_for_new_records(ems.orchestration_stacks.reload, hashes, :ems_ref)

      save_orchestration_stack_nesting(stacks.index_by(&:id), hashes)
    end

    def save_orchestration_stack_nesting(stacks, hashes)
      hashes.each do |hash|
        next unless hash[:parent]
        stacks[hash[:id]].update_attribute(:parent_id, hash[:parent][:id]) if stacks[hash[:id]]
      end
    end

    def save_parameters_inventory(orchestration_stack, hashes)
      save_inventory_multi(orchestration_stack.parameters,
                           hashes,
                           :use_association,
                           [:ems_ref])
    end

    def save_outputs_inventory(orchestration_stack, hashes)
      save_inventory_multi(orchestration_stack.outputs,
                           hashes,
                           :use_association,
                           [:ems_ref])
    end

    def save_resources_inventory(orchestration_stack, hashes)
      save_inventory_multi(orchestration_stack.resources,
                           hashes,
                           :use_association,
                           [:ems_ref])
    end
  end
end
