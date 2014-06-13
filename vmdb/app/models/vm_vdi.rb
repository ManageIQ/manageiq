class VmVdi
  def self.method_missing(method_sym, *arguments, &block)
    Vm.where(:vdi => true).send(method_sym, *arguments, &block)
  end

  def self.respond_to?(method, include_private = false)
    Vm.where(:vdi => true).respond_to?(method, include_private)
  end

  def self.queue_mark_as_vdi(ids)
    queue_task(:mark_as_vdi, "Create VDI Desktops for #{ids.length} VM(s)", ids)
  end

  def self.mark_as_vdi(ids, task_id)
    begin
      results = {:error => 0, :ok => 0, :total => ids.length, :success_msgs => [], :error_msgs => [], :warning_msgs => []}
      task = MiqTask.find_by_id(task_id)
      task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Running task")
      VmOrTemplate.where(:id => ids).each do |vm|
        begin
          VdiDesktop.create_desktop_for_vm(vm)
          results[:ok] += 1
        rescue MiqException::Error
          results[:error] += 1
        end
      end

      results[:success_msgs] << "Successfully marked #{results[:ok]} VM(s) as VDI Desktop(s)" unless results[:ok].zero?
      results[:error_msgs]   << "Failed to mark #{results[:error]} VM(s) as VDI Desktop(s)"   unless results[:error].zero?
      task.task_results = results
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Task Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def self.mark_as_non_vdi(ids, task_id)
    begin
      results = {:error => 0, :ok => 0, :total => ids.length, :success_msgs => [], :error_msgs => [], :warning_msgs => []}
      task = MiqTask.find_by_id(task_id)
      task.update_status(MiqTask::STATE_ACTIVE, MiqTask::STATUS_OK, "Running task")
      VdiDesktop.where(:id => ids).each do |vdi_desktop|
        begin
          vdi_desktop.remove_desktop_for_vm
          results[:ok] += 1
        rescue MiqException::Error
          results[:error] += 1
        end
      end

      results[:success_msgs] << "Successfully un-marked #{results[:ok]} VDI Desktop(s)" unless results[:ok].zero?
      results[:error_msgs]   << "Failed to un-mark #{results[:error]} VDI Desktop(s)"   unless results[:error].zero?
      task.task_results = results

      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_OK, "Task Complete")
    rescue => err
      task.update_status(MiqTask::STATE_FINISHED, MiqTask::STATUS_ERROR, err.to_s)
      $log.log_backtrace(err)
    end
  end

  def self.queue_task(task_name, task_description, ids)
    log_header = "MIQ(VmVdi.queue_task)"

    task = MiqTask.create(:name => task_description, :userid => User.current_userid || 'system')

    $log.info("#{log_header} Queuing VmVdi task <#{task_name}>  Description: #{task_description}")
    cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
    MiqQueue.put(
      :class_name   => self.name,
      :args         => [ids, task.id],
      :method_name  => task_name,
      :miq_callback => cb,
      :zone         => MiqServer.my_zone,
      :priority     => MiqQueue::HIGH_PRIORITY
    )
    task.state_queued
    task
  end
end
