class ApiController
  module Chargeback
    # Request
    # {
    #   "action":"assign",
    #
    #   "kind": "tenant",
    #   "c_id": 1
    # }
    def chargebacks_assign_resource(object, _type, _id, data)
      klass = data['kind'].camelcase.constantize
      obj = klass.find(data['c_id'])

      ChargebackRate.set_assignments object.rate_type, [{:cb_rate => object, :object => obj}]

      {:tags => object.tags}
    end

    # Request
    # {
    #   "action":"unassign",
    #
    #   "kind": "tenant",
    #   "c_id": 1
    # }
    def chargebacks_unassign_resource(object, _type, _id, data = nil)
      obj_name = data['kind']
      obj_id   = data['c_id']
      tag_name = "/chargeback_rate/assigned_to/#{obj_name}/id/#{obj_id}"

      object.tags = object.tags.reject { |t| t.name == tag_name }

      {:tags => object.tags}
    end

    def update_chargebacks
      validate_api_action
      if @req.subcollection
        render_normal_update :chargebacks, update_collection(:chargebacks, @req.s_id, true)
      else
        render_normal_update :chargebacks, update_collection(:chargebacks, @req.c_id)
      end
    end
  end
end
