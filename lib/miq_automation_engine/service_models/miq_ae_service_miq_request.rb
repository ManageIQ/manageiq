module MiqAeMethodService
  class MiqAeServiceMiqRequest < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_miq_request_mixin"
    include MiqAeServiceMiqRequestMixin

    expose :miq_request_tasks, :association => true
    expose :requester,         :association => true
    expose :resource,          :association => true
    expose :source,            :association => true
    expose :destination,       :association => true
    expose :tenant,            :association => true
    expose :authorized?
    expose :approve,   :override_return => true
    expose :deny,      :override_return => true
    expose :pending,   :override_return => true

    # For backward compatibility
    def miq_request
      self
    end
    association :miq_request

    def approvers
      ar_method { wrap_results @object.miq_approvals.collect { |a| a.approver.kind_of?(User) ? a.approver : nil }.compact }
    end
    association :approvers

    def set_message(value)
      object_send(:update_attributes, :message => value.try!(:truncate, 255))
    end

    def description=(new_description)
      object_send(:update_attributes, :description => new_description)
    end
  end
end
