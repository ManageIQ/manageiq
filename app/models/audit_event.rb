class AuditEvent < ApplicationRecord
  validates :event, :status, :message, :severity, :presence => true
  validates :status, :inclusion => {:in => %w[success failure]}
  validates :severity, :inclusion => {:in => %w[fatal error warn info debug]}

  include Purging

  def self.generate(attrs)
    attrs = {
      :severity => "info",
      :status   => "success",
      :userid   => "system",
    }.merge(attrs)

    attrs[:source] ||= source(caller_locations(1, 1).first)

    event = AuditEvent.create(attrs)

    # Cut an Audit log message
    $audit_log.send(attrs[:status], "Username [#{attrs[:userid]}], from: [#{attrs[:source]}], #{attrs[:message]}")
    event
  end

  def self.success(attrs)
    AuditEvent.generate(attrs.merge(:status => "success", :source => source(caller_locations(1, 1).first)))
  end

  def self.failure(attrs)
    AuditEvent.generate(attrs.merge(:status => "failure", :severity => "warn", :source => source(caller_locations(1, 1).first)))
  end

  def self.source(one_caller_location)
    "#{File.basename(one_caller_location.path, '.*').classify}.#{one_caller_location.label}"
  end
end
