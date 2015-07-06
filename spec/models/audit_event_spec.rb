require "spec_helper"

describe AuditEvent do
  it "should be invalid with empty attributes" do
    event = AuditEvent.new
    event.should_not be_valid
    event.errors.should include(:event)
    event.errors.should include(:status)
    event.errors.should include(:message)
    event.errors.should include(:severity)
  end

  it "should test for valid status" do
    ok  = ["success", "failure"]
    bad = ["bad", "worse"]

    ok.each do |status|
      event = AuditEvent.new(:event => "test_valid_status", :message => "test_valid_status - message", :severity => "info")
      event.status = status
      event.should be_valid
    end

    bad.each do |status|
      event = AuditEvent.new(:event => "test_invalid_status", :message => "test_invalid_status - message", :severity => "info")
      event.status = status
      event.should_not be_valid
    end
  end

  it "should test for valid severity" do
    ok  = ["fatal", "error", "warn", "info", "debug"]
    bad = ["bad", "worse"]

    ok.each {|sev|
      event = AuditEvent.new(:event => "test_valid_severity", :message => "test_valid_severity - message",   :status => "success")
      event.severity = sev
      event.should be_valid
    }

    bad.each {|sev|
      event = AuditEvent.new(:event => "test_invalid_severity", :message => "test_invalid_severity - message",   :status => "success")
      event.severity = sev
      event.should_not be_valid
    }
  end

  def test_valid_source(tmpl)
    source = "AuditEventSpec.test_valid_source"

    event = AuditEvent.success(tmpl)
    event.source.should == source

    event = AuditEvent.failure(tmpl)
    event.source.should == source

    event = AuditEvent.generate(tmpl.merge(:status => "success", :severity => "info"))
    event.source.should == source
  end

  it "should test for valid source" do
    tmpl = {
      :event   => "test_valid_source",
      :message => "test_valid_source - message"
    }

    test_valid_source(tmpl)
  end
end
