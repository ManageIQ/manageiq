class AuditEvent < ApplicationRecord
  validates :event, :status, :message, :severity, :presence => true
  validates :status, :inclusion => { :in => %w(success failure) }
  validates :severity, :inclusion => { :in => %w(fatal error warn info debug) }

  def self.generate(attrs)
    attrs = {
      :severity => "info",
      :status   => "success",
      :userid   => "system",
      :source   => AuditEvent.source(caller)
    }.merge(attrs)

    event = AuditEvent.create(attrs)

    # Cut an Audit log message
    $audit_log.send(attrs[:status], "MIQ(#{attrs[:source]}) userid: [#{attrs[:userid]}] - #{attrs[:message]}")
    event
  end

  def self.success(attrs)
    AuditEvent.generate(attrs.merge(:status => "success", :source => AuditEvent.source(caller)))
  end

  def self.failure(attrs)
    AuditEvent.generate(attrs.merge(:status => "failure", :severity => "warn", :source => AuditEvent.source(caller)))
  end

  def self.source(source)
    /^([^:]+):[^`]+`([^']+).*$/ =~ source[0]
    "#{File.basename($1, ".*").camelize}.#{$2}"
  end
end
