module Api
  class SharedVmsController < BaseController
    def index
      shared_vms = Vm.joins(:shares).where(:shares => {:id => Rbac.resources_shared_with(User.current_user)})

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
      shared_vm = Vm
                  .joins(:shares)
                  .where(:shares => {:id => Rbac.resources_shared_with(User.current_user)})
                  .find(@req.c_id)
      render_resource(:shared_vms, shared_vm)
    end
  end
end
