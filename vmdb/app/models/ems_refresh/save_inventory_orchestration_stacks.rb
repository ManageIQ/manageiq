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

      ems.orchestration_stacks(true)
      deletes = target == ems ? ems.orchestration_stacks.dup : []

      hashes.each do |h|
        h[:orchestration_template_id] = h.fetch_path(:orchestration_template, :id)
      end

      stacks = save_inventory_multi(:orchestration_stacks,
                                    ems,
                                    hashes,
                                    deletes,
                                    [:ems_ref],
                                    [:parameters, :outputs, :resources],
                                    [:parent, :orchestration_template])
      store_ids_for_new_records(ems.orchestration_stacks, hashes, :ems_ref)

      save_orchestration_stack_nesting(stacks.index_by(&:id), hashes)
    end

    def save_orchestration_stack_nesting(stacks, hashes)
      hashes.each do |hash|
        next unless hash[:parent]
        stacks[hash[:id]].update_attribute(:parent_id, hash[:parent][:id])
      end
    end

    def save_parameters_inventory(orchestration_stack, hashes)
      deletes = orchestration_stack.parameters(true).dup

      save_inventory_multi(:parameters,
                           orchestration_stack,
                           hashes,
                           deletes,
                           [:ems_ref])
    end

    def save_outputs_inventory(orchestration_stack, hashes)
      deletes = orchestration_stack.outputs(true).dup

      save_inventory_multi(:outputs,
                           orchestration_stack,
                           hashes,
                           deletes,
                           [:ems_ref])
    end

    def save_resources_inventory(orchestration_stack, hashes)
      deletes = orchestration_stack.resources(true).dup

      save_inventory_multi(:resources,
                           orchestration_stack,
                           hashes,
                           deletes,
                           [:ems_ref])
    end
  end
end
