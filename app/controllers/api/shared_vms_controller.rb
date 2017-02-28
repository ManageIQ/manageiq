module Api
  class SharedVmsController < BaseController
    def index
      resources = Rbac.resources_shared_with(User.current_user)
      # TODO: if this is a relation, we need to filter in SQL
      shared_vms = resources.select { |resource| resource.kind_of?(Vm) }

      # # Roughly what we do elsewhere:
      # miq_expression = filter_param(Vm)

      # # can't sort - it's an array
      # sort_options = sort_params(klass) if shared_vms.respond_to?(:reorder)

      # shared_vms = shared_vms.reorder(sort_options) if sort_options.present?

      # options = {}
      # options[:order] = sort_options if sort_options.present?
      # options[:offset], options[:limit] = expand_paginate_params if paginate_params?
      # options[:filter] = miq_expression if miq_expression

      # shared_vms = Rbac.filtered(shared_vms, options)

      render_collection(:shared_vms, shared_vms)
    end

    def show
      resources = Rbac.resources_shared_with(User.current_user)
      shared_vm = resources.select { |resource| resource.kind_of?(Vm) }
                           .detect { |resource| resource.id == @req.c_id }
      raise NotFoundError unless shared_vm
      render_resource(:shared_vms, shared_vm)
    end
  end
end
