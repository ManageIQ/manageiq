# frozen_string_literal: true

#
# Description: Set finished message for provision object
#
module ManageIQ
  module Automate
    module System
      module CommonMethods
        module StateMachineMethods
          class TaskFinished
            def initialize(handle = $evm)
              @handle = handle
            end

            def main
              task_finished
            end

            private

            def task
              prov_obj_name = @handle.root['vmdb_object_type']
              @handle.root[prov_obj_name]
            end

            def task_finished
              final_message = "[#{@handle.root['miq_server'].name}] "

              case @handle.root['vmdb_object_type']
              when 'service_template_provision_task'
                final_message += "Service [#{task.destination.name}] Provisioned Successfully"
                notified = @handle.vmdb('notification').where('options LIKE ?',"%#{final_message}%")
                @handle.create_notification(:type => :automate_service_provisioned, :subject => task.destination) if task.miq_request_task.nil? && notified.count < 1 
              when 'miq_provision'
                if task.get_option(:request_type) == :clone_to_template
                  final_message += "Template [#{task.get_option(:vm_target_name)}] Published Successfully"
                  @handle.create_notification(:type => :automate_template_published, :subject => task.vm)
                else
                  final_message += "VM [#{task.get_option(:vm_target_name)}] "
                  final_message += "IP [#{task.vm.ipaddresses.first}] " if task.vm&.ipaddresses.present?
                  final_message += "Provisioned Successfully"
                  @handle.create_notification(:type => :automate_vm_provisioned, :subject => task.vm)
                end
              else
                final_message += @handle.inputs['message']
              end

              task.miq_request.user_message = final_message
              task.finished(final_message)
            end
          end
        end
      end
    end
  end
end

ManageIQ::Automate::System::CommonMethods::StateMachineMethods::TaskFinished.new.main
