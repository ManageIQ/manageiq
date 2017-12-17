class ManageIQ::Providers::NativeOperationWorkflow < ManageIQ::Providers::EmsRefreshWorkflow
  def post_refresh
    notification_options = {
      :target_name => target_entity.name,
      :method      => options[:method]
    }

    if status == "ok"
      type = :provider_operation_success
    else
      type = :provider_operation_failure
      notification_options[:error] = message
    end

    Notification.create(:type => type, :options => notification_options)

    queue_signal(:finish, message, status)
  end
end
