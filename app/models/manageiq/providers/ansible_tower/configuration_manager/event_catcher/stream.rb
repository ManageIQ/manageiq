class ManageIQ::Providers::AnsibleTower::ConfigurationManager::EventCatcher::Stream
  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  def initialize(ems)
    @ems = ems
    @last_activity = nil
    @stop_polling = false
  end

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
              yield activity
              @last_activity = activity
            end
            sleep(20)
          end
        rescue => exception
          raise ProviderUnreachable, exception.message
        end
      end
    end
  end

  private

  def filter
    {
      :order_by      => 'timestamp',
      :timestamp__gt => @last_activity ? @last_activity.timestamp : 1.minute.ago.to_s(:db)
    }
  end
end
