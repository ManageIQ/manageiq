class AuditEvent < ActiveRecord::Base
  include ReportableMixin

  validates_presence_of     :event, :status, :message, :severity
  validates_inclusion_of    :status,   :in => ["success", "failure"]
  validates_inclusion_of    :severity, :in => ["fatal", "error", "warn", "info", "debug"]

  def self.generate(attrs)
    attrs = {
      :severity       =>  "info",
      :status         =>  "success",
      :userid         =>  "system",
      :source         =>  AuditEvent.source(caller)
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

  private

  def self.source(source)
    %r{^([^:]+):[^`]+`([^']+).*$} =~ source[0]
    "#{File.basename($1, ".*").camelize}.#{$2}"
  end

end
