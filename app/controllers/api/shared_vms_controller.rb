module Api
  class SharedVmsController < BaseController
    def index
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
      render_resource(:shared_vms, shared_vms.find(@req.c_id))
    end

    private

    def shared_vms
      Vm.joins(:shares).where(:shares => {:id => Rbac.resources_shared_with(User.current_user)})
    end
  end
end
