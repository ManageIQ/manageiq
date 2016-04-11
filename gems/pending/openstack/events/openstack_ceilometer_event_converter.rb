class OpenstackCeilometerEventConverter
  def initialize(event)
    @event = event
    @payload = hashize_traits(event.traits)
  end

  def metadata
    {:user_id => nil, :priority => nil, :content_type => nil}
  end

  def payload
    {
      "message_id" => @event.message_id,
      "event_type" => @event.event_type,
      "timestamp"  => @event.generated,
      "payload"    => @payload,
    }
  end

  private

  def hashize_traits(traits_list)
    output = {}
    traits_list.each do |property|
      output[property["name"]] = property["value"]
    end
    output
  end
end
