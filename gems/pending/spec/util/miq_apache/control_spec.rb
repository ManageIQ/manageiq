require "spec_helper"

describe MiqApache::Control do
  it "should run_apache_cmd with start when calling start" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('start')
    MiqApache::Control.start
  end

  it "should run_apache_cmd with graceful-stop and start when calling restart with graceful true" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('graceful-stop')
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('start')
    MiqApache::Control.restart(true)
  end

  it "should run_apache_cmd with restart when calling restart with graceful false" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('restart')
    MiqApache::Control.restart(false)
  end

  it "should run_apache_cmd with graceful-stop when calling stop with graceful true" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('graceful-stop')
    MiqApache::Control.stop(true)
  end

  it "should run_apache_cmd with stop when calling stop with graceful false" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).with('stop')
    MiqApache::Control.stop(false)
  end

  it "should run_apache_cmd with /usr/bin/systemctl status httpd status when calling httpd_status" do
    expect(MiqUtil).to receive(:runcmd).with('/usr/bin/systemctl status httpd').and_return("Active: active")
    MiqApache::Control.httpd_status
  end

  it "should return false with result when calling httpd_status raising 'httpd is stopped' RuntimeError" do
    result = "Active: inactive"
    allow(MiqUtil).to receive(:runcmd).and_raise(RuntimeError.new(result))
    expect(MiqApache::Control.httpd_status).to eq([false, result])
  end

  it "should return false with result when calling httpd_status raising 'Active: inactive' RuntimeError" do
    result = "Active: inactive"
    allow(MiqUtil).to receive(:runcmd).and_raise(RuntimeError.new(result))
    expect(MiqApache::Control.httpd_status).to eq([false, result])
  end

  it "should return true with result when calling httpd_status raising 'Active: inactive' RuntimeError" do
    result = "Active: active"
    allow(MiqUtil).to receive(:runcmd).and_return(result)
    expect(MiqApache::Control.httpd_status).to eq([true, result])
  end

  it "should raise an error when calling httpd_status raising unknown result RuntimeError" do
    result = "unknown result"
    allow(MiqUtil).to receive(:runcmd).and_raise(RuntimeError.new(result))
    expect { MiqApache::Control.httpd_status }.to raise_error(RuntimeError)
  end

  it "should runcmd with killall -9 httpd when running kill_all and cleanup file descriptors" do
    expect(MiqUtil).to receive(:runcmd).with("killall -9 httpd")
    expect(MiqUtil).to receive(:runcmd).with(start_with "for i in")
    MiqApache::Control.kill_all
  end

  it "should raise an error if killall failed with unknown result" do
    result = "unknown result"
    allow(MiqUtil).to receive(:runcmd).and_raise(RuntimeError.new(result))
    expect { MiqApache::Control.kill_all }.to raise_error(RuntimeError)
  end

  it "should not raise an error if the kill returned no process found" do
    result = "httpd: no process found"
    allow(MiqUtil).to receive(:runcmd).and_raise(RuntimeError.new(result))
    expect { MiqApache::Control.kill_all }.not_to raise_error
  end

  # FIXME: need to implement the code and change the test
  it "should not do anything when calling status with full true" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).never
    expect(MiqApache::Control.status(true)).to be_nil
  end

  # FIXME: need to implement the code and change the test
  it "should not do anything when calling status with full false" do
    expect(MiqApache::Control).to receive(:run_apache_cmd).never
    expect(MiqApache::Control.status(false)).to be_nil
  end

  it "should return true with when calling config_ok? and result was 'Syntax OK'" do
    result = "Syntax OK"
    allow(MiqUtil).to receive(:runcmd).and_return(result)
    expect(MiqApache::Control).to be_config_ok
  end

  it "should return false with when calling config_ok? and an error was raised" do
    allow(MiqUtil).to receive(:runcmd).and_raise("some error message")
    expect(MiqApache::Control).not_to be_config_ok
  end

  it "should return false with when calling config_ok? and result was NOT 'Syntax OK'" do
    result = "Blah!"
    allow(MiqUtil).to receive(:runcmd).and_return(result)
    expect(MiqApache::Control).not_to be_config_ok
  end

  it "should runcmd with rpm -qa... when calling version" do
    expect(MiqUtil).to receive(:runcmd).with("rpm -qa --queryformat '%{VERSION}' httpd")
    MiqApache::Control.version
  end

  it "should make the apache control log's directory if missing when calling run_apache_cmd" do
    allow(File).to receive(:exist?).and_return(false)
    expect(Dir).to receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG))
    allow(MiqUtil).to receive(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should not make the apache control log's directory if it exists when calling run_apache_cmd" do
    allow(File).to receive(:exist?).and_return(true)
    expect(Dir).to receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG)).never
    allow(MiqUtil).to receive(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(false)
    expect(MiqUtil).to receive(:runcmd).with("apachectl #{cmd}")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start in debug mode if $log is debug" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(true)
    expect(MiqUtil).to receive(:runcmd).with("apachectl #{cmd}")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should log a warning when calling run_apache_cmd with start that raises an error" do
    cmd = "start"
    allow(File).to receive(:exist?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    allow($log).to receive(:debug?).and_return(false)
    allow(MiqUtil).to receive(:runcmd).and_raise("warn")
    expect($log).to receive(:warn)
    MiqApache::Control.run_apache_cmd("start")
  end
end
