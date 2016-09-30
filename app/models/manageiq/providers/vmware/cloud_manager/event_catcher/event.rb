# Message format description:
# https://pubs.vmware.com/vca/index.jsp#com.vmware.vcloud.api.doc_56/GUID-7C1F16FF-C530-404E-8533-329670B20A19.html

class ManageIQ::Providers::Vmware::CloudManager::EventCatcher::Event
  attr_accessor :payload, :metadata, :delivery_info

  TYPE_KEY              = 'notification.type'.freeze
  ORGANIZATION_UUID_KEY = 'notification.orgUUID'.freeze
  ENTITY_TYPE_KEY       = 'notification.entityType'.freeze
  ENTITY_UUID_KEY       = 'notification.entityUUID'.freeze
  TIMESTAMP_KEY         = 'notification.timestamp'.freeze

  def required_header_keys
    [TYPE_KEY, ORGANIZATION_UUID_KEY, ENTITY_TYPE_KEY, ENTITY_UUID_KEY, TIMESTAMP_KEY]
  end

  def initialize(payload, metadata, delivery_info)
    raise "AMQP message missing header" unless metadata.respond_to? :headers
    raise "AMQP message missing required headers" if required_header_keys.any? { |s| !metadata.headers.key? s }

    @payload       = payload
    @payload_hash  = payload_hash
    @metadata      = metadata
    @delivery_info = delivery_info
  end

  def header(key)
    @metadata.headers[key]
  end

  def payload_hash
    begin
      @payload_hash ||= { :eventId => Hash.from_xml(@payload)['Notification']['eventId'] }
    rescue
      raise "AMQP message invalid payload"
    end
    @payload_hash
  end

  def type
    t = header TYPE_KEY
    if t.nil?
      return ""
    end
    t
  end

  # Serialization.
  def to_hash
    {
      :id                => payload_hash[:eventId],
      :type              => type,
      :organization_uuid => header(ORGANIZATION_UUID_KEY),
      :entity_type       => header(ENTITY_TYPE_KEY),
      :entity_uuid       => header(ENTITY_UUID_KEY),
      :timestamp         => header(TIMESTAMP_KEY),
    }
  end
end
