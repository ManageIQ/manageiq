class ServiceProvisionTask < MiqProvisionTask
    alias_method :service, :destination

    # Is this an issue? think we want different states?
    # TODO: validates_inclusion_of :state, :in => %w[pending queued active provisioned finished], :message => "should be pending, queued, active, provisioned or finished"

    # include StateMachine

    def description
      'Provision Service'
    end

    def self.base_model
      ServiceProvisionTask
    end

    def self.request_class
      # TODO: determine the ServiceProvisionRequest (think this is terraform specific)
      PhysicalServerProvisionRequest
    end

    def model_class
      Service
    end

    def deliver_to_automate(*)
        # TODO: generic life cycle / service_provision
      super('physical_server_provision', my_zone)
    end

    ## State Machine

    attr_accessor :task_id # if waiting on execute (only used in execute_wait)

    def action
        "Provision"
    end

    def signal(new_state)
        @state = new_state
    end

    def transition(old_state, new_state, message = "#{old_state} Complete")
        update!(:message => message)
        signal new_state
    end

    def do_start
        signal :preprocess
    end

    def do_preprocess
        update!(:message => "Preprocess Started")
        service.preprocess(action)
        update!(:message => "Preprocess Complete")
        signal :execute
    end

    def do_execute
        if service.respond_to?(:execute_async)
            update!(:message => "Execute (async) Started")
            # TODO where do we store this?
            @task_id = service.execute_async(action)
            signal :execute_wait
        else
            update!(:message => "Preprocess Started")
            service.execute(action)
            update!(:message => "Preprocess Complete")
            signal :check_complete
        end
    end

    # wait for the execute to
    def do_execute_wait
        if task.state != ::MiqTask::STATE_FINISHED
            # stay in this state
        elsif !task.status_ok?
            signal :issues
        else
            update!(:message => "Execute (wait) Complete")
            signal :check_complete
        end
    end

    def do_check_complete
        update!(:message => "CheckComplete Started")
        done, message = service.check_complete(stage, miq_request)

        if !done
            # retry, counts, timeout
        elsif message.blank?
            update!(:message => "CheckComplete Complete")
            signal :refresh
        else
            update!(:message => "CheckComplete failed with error #{message}")
            signal :finish
        end
    end

    def do_refresh
        update!(:message => "refresh Started")
        service.refresh(action)
        update!(:message => "refresh Complete")
        signal :check_refresh
    end

    def do_check_refresh
        update!(:message => "CheckRefresh Started")
        done, message = service.check_refresh(stage, miq_request)

        if !done
            # retry, counts, timeout
        elsif message.blank?
            update!(:message => "CheckRefresh Complete")
            signal :postprocess
        else
            update!(:message => "CheckRefresh failed with error #{message}")
            signal :finish
        end
    end

    def do_postprocess
        update!(:message => "Postprocess Started")
        service.postprocess(action)
        update!(:message => "Postprocess Complete")
        signal :finish
    end

    def do_finish
    end
end