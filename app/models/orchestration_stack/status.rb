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

    def rollbacked?
      false
    end

    def deleted?
      false
    end

    # in a non-transitional state
    def completed?
      succeeded? || failed? || rollbacked? || deleted?
    end

    def normalized_status
      return ['transient', reason || status] unless completed?

      if succeeded?
        ['create_complete', reason || 'OK']
      elsif rollbacked?
        ['rollback_complete', reason || 'Stack was rolled back']
      elsif deleted?
        ['delete_complete', reason || 'Stack was deleted']
      else
        ['failed', reason || 'Stack creation failed']
      end
    end
  end
end
