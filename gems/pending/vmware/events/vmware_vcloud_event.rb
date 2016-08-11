# https://pubs.vmware.com/vca/index.jsp#com.vmware.vcloud.api.doc_56/GUID-7C1F16FF-C530-404E-8533-329670B20A19.html
#
# EXAMPLE PAYLOAD:
# {
# "eventId"           : "a1440dd8-60ae-46c7-b216-44693bc00c90",
# "type"              : "com/vmware/vcloud/event/blockingtask/create",
# "timestamp"         : "2011-06-18T14:33:27.787+03:00",
# "operationSuccess"  : true,
# "user"              : "urn:vcloud:user:44",
# "org"               : "urn:vcloud:org:70",
# "entity"            : "urn:vcloud:blockingTask:25"
# "task"              : "urn:vcloud:task:34",
# "taskOwner"         : "urn:vcloud:vapp:26"
# }

class VmwareVcloudEvent
  attr_accessor :payload, :metadata

  EVENT_ID_KEY = "eventId".freeze
  EVENT_TYPE_KEY = "type".freeze

  def initialize(payload, metadata)
    raise "AMQP message missing raquired keys" if [EVENT_ID_KEY, EVENT_TYPE_KEY].any? { |s| !payload.key? s }

    @payload = payload
    @metadata = metadata
  end

  def type
    @payload[EVENT_TYPE_KEY]
  end

  def to_hash
    {
      :event_id    => @payload[EVENT_ID_KEY],
      :event_type  => @payload[EVENT_TYPE_KEY],
      :timestamp   => @payload["timestamp"],
      :user_id     => @payload["user"],
      :instance_id => @payload["taskOwner"]
    }
  end
end
