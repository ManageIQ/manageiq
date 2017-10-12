class Service
  class LinkingWorkflow < ManageIQ::Providers::EmsRefreshWorkflow
    def load_transitions
      self.state ||= 'initialize'

      {
        :initializing => {'initialize'       => 'waiting_to_start'},
        :start        => {'waiting_to_start' => 'running'},
        :refresh      => {'running'          => 'refreshing'},
        :poll_refresh => {'refreshing'       => 'refreshing'},
        :post_refresh => {
          'running'    => 'post_refreshing',
          'refreshing' => 'post_refreshing'
        },
        :finish       => {'*'                => 'finished'},
        :abort_job    => {'*'                => 'aborting'},
        :cancel       => {'*'                => 'canceling'},
        :error        => {'*'                => '*'}
      }
    end

    def run_native_op
      _log.info("Enter")

      unless linking_service
        msg = "Job [%{id}] [%{name}] aborted: didn't find service ID: [%{service_id}] to link to" % {
          :id => id, :name => name, :service_id => options[:service_id]
        }
        _log.error(msg)
        signal(:abort, msg, 'error')
      end

      unless target_entity
        msg = "Job [%{id}] [%{name}] aborted: didn't find provider class: [%{target_class}] ID: [%{target_id}] to refresh" % {
          :id => id, :name => name, :target_class => target_class, :target_id => target_id
        }
        _log.error(msg)
        signal(:abort, msg, 'error')
      end

      if find_all_targets?
        set_status("all VMs are found in DB")
        signal(:post_refresh)
      else
        set_status("calling refresh")
        queue_signal(:refresh)
      end
    end
    alias_method :start, :run_native_op

    def post_refresh
      _log.info("Enter")

      found_vms = linking_targets
      not_found_vms = options[:uid_ems_array] - found_vms.pluck(:uid_ems)
      _log.warn("VMs not found for linking to service ID [#{service.id}], name [#{service.name}]: #{not_found_vms}") unless not_found_vms.blank?

      service = linking_service
      found_vms.each { |vm| service.add_resource!(vm) }
      signal(:finish, "linking VMs to service is complete", "ok")
    rescue => err
      _log.log_backtrace(err)
      signal(:abort, err.message, "error")
    end

    private

    def find_all_targets?
      linking_targets.length == options[:uid_ems_array].length
    end

    def linking_targets
      @linking_targets ||= VmOrTemplate.where(:uid_ems => options[:uid_ems_array], :ems_id => target_id)
    end

    def linking_service
      @linking_service ||= Service.find_by(:id => options[:service_id])
    end
  end
end
