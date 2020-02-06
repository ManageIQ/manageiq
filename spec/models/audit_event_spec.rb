RSpec.describe AuditEvent do
  it "should be invalid with empty attributes" do
    event = AuditEvent.new
    expect(event).not_to be_valid
    expect(event.errors).to include(:event)
    expect(event.errors).to include(:status)
    expect(event.errors).to include(:message)
    expect(event.errors).to include(:severity)
  end

  it "should test for valid status" do
    ok  = ["success", "failure"]
    bad = ["bad", "worse"]

    ok.each do |status|
      event = AuditEvent.new(:event => "test_valid_status", :message => "test_valid_status - message", :severity => "info")
      event.status = status
      expect(event).to be_valid
    end

    bad.each do |status|
      event = AuditEvent.new(:event => "test_invalid_status", :message => "test_invalid_status - message", :severity => "info")
      event.status = status
      expect(event).not_to be_valid
    end
  end

  it "should test for valid severity" do
    ok  = ["fatal", "error", "warn", "info", "debug"]
    bad = ["bad", "worse"]

    ok.each do |sev|
      event = AuditEvent.new(:event => "test_valid_severity", :message => "test_valid_severity - message",   :status => "success")
      event.severity = sev
      expect(event).to be_valid
    end

    bad.each do |sev|
      event = AuditEvent.new(:event => "test_invalid_severity", :message => "test_invalid_severity - message",   :status => "success")
      event.severity = sev
      expect(event).not_to be_valid
    end
  end

  def test_valid_source(tmpl)
    source = "AuditEventSpec.test_valid_source"

    event = AuditEvent.success(tmpl)
    expect(event.source).to eq(source)

    event = AuditEvent.failure(tmpl)
    expect(event.source).to eq(source)

    event = AuditEvent.generate(tmpl.merge(:status => "success", :severity => "info"))
    expect(event.source).to eq(source)
  end

  it "should test for valid source" do
    tmpl = {
      :event   => "test_valid_source",
      :message => "test_valid_source - message"
    }

    test_valid_source(tmpl)
  end
end
