module ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventCatcher::Stream
  def start
    @stop_polling = false
  end

  def stop
    @stop_polling = true
  end

  def poll
    @ems.with_provider_connection do |ansible|
      catch(:stop_polling) do
        begin
          loop do
            ansible.api.activity_stream.all(filter).each do |activity|
              throw :stop_polling if @stop_polling
              yield activity.to_h
              @last_activity = activity
            end
            sleep @poll_sleep
          end
        rescue => exception
          provider_module = ManageIQ::Providers::Inflector.provider_module(self.class)
          raise provider_module::AutomationManager::EventCatcher::Stream::ProviderUnreachable, exception.message
        end
      end
    end
  end

  private

  def filter
    timestamp = @last_activity ? Time.zone.parse(@last_activity.timestamp.to_s) : 1.minute.ago
    {
      :order_by      => 'timestamp',
      :timestamp__gt => timestamp.to_s(:db)
    }
  end
end
