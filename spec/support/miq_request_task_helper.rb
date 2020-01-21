module Spec
  module Support
    module MiqRequestTaskHelper
      def call_method
        @called_states << @current_state
        task.update(:phase => @current_state)
        check_post_install_callback
        task.send(@current_state)
      end

      def check_post_install_callback
        return if @skip_post_install_check
        allow(task).to receive(:for_destination)
        task.post_install_callback
      end

      def dequeue_method
        return unless (method = @queue.shift)
        if method.to_s.start_with?("test_")
          send(method)
        else
          @current_state = method
          send("test_#{@current_state}")
        end
        true
      end

      def requeue_phase(method = @current_state)
        @queue.unshift(method)
        nil
      end

      def skip_post_install_check
        @skip_post_install_check = true
        yield
        @skip_post_install_check = false
      end
    end
  end
end

Dir.glob(Rails.root.join("spec", "models", "**", "state_machine_spec_helper.rb")).each { |file| require file }
