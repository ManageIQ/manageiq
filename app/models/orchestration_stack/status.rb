class OrchestrationStack
  class Status
    attr_accessor :status
    attr_accessor :reason

    def initialize(status, reason)
      self.status = status
      self.reason = reason
    end

    def succeeded?
      false
    end

    def failed?
      false
    end

    def rolled_back?
      false
    end

    def deleted?
      false
    end

    def canceled?
      false
    end

    def updated?
      false
    end

    # in a non-transient state
    def completed?
      succeeded? || failed? || rolled_back? || deleted? || canceled? || updated?
    end

    def normalized_status
      return ['transient', reason || status] unless completed?

      if succeeded?
        ['create_complete', reason || 'OK']
      elsif rolled_back?
        ['rollback_complete', reason || 'Stack was rolled back']
      elsif deleted?
        ['delete_complete', reason || 'Stack was deleted']
      elsif canceled?
        ['create_canceled', reason || 'Stack creation was canceled']
      elsif updated?
        ['update_complete', reason || 'OK']
      elsif reason == 'Service_Template_Provisioning failed'
        ['failed', reason || 'Stack creation failed']
      else
        ['failed', reason]
      end
    end
  end
end
