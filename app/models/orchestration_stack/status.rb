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

    # in a non-transient state
    def completed?
      succeeded? || failed? || rolled_back? || deleted? || canceled?
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
      else
        ['failed', reason || 'Stack creation failed']
      end
    end
  end
end
