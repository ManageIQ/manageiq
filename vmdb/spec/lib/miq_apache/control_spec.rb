require "spec_helper"

describe MiqApache::Control do
  it "should run_apache_cmd with start when calling start" do
    MiqApache::Control.should_receive(:run_apache_cmd).with('start')
    MiqApache::Control.start
  end

  it "should run_apache_cmd with graceful-stop and start when calling restart with graceful true" do
    MiqApache::Control.should_receive(:run_apache_cmd).with('graceful-stop')
    MiqApache::Control.should_receive(:run_apache_cmd).with('start')
    MiqApache::Control.restart(true)
  end

  it "should run_apache_cmd with restart when calling restart with graceful false" do
    MiqApache::Control.should_receive(:run_apache_cmd).with('restart')
    MiqApache::Control.restart(false)
  end

  it "should run_apache_cmd with graceful-stop when calling stop with graceful true" do
    MiqApache::Control.should_receive(:run_apache_cmd).with('graceful-stop')
    MiqApache::Control.stop(true)
  end

  it "should run_apache_cmd with stop when calling stop with graceful false" do
    MiqApache::Control.should_receive(:run_apache_cmd).with('stop')
    MiqApache::Control.stop(false)
  end


  it "should run_apache_cmd with /etc/init.d/httpd status when calling httpd_status" do
    MiqUtil.should_receive(:runcmd).with('/etc/init.d/httpd status').and_return("is running...\n")
    MiqApache::Control.httpd_status
  end

  it "should return false with result when calling httpd_status raising 'httpd is stopped' RuntimeError" do
    result = "httpd is stopped"
    MiqUtil.stub(:runcmd).and_raise(RuntimeError.new(result))
    MiqApache::Control.httpd_status.should == [false, result]
  end

  it "should return false with result when calling httpd_status raising 'httpd dead but pid file exists' RuntimeError" do
    result = "httpd dead but pid file exists"
    MiqUtil.stub(:runcmd).and_raise(RuntimeError.new(result))
    MiqApache::Control.httpd_status.should == [false, result]
  end

  it "should return true with result when calling httpd_status raising 'httpd dead but pid file exists' RuntimeError" do
    result = "is running...\n"
    MiqUtil.stub(:runcmd).and_return(result)
    MiqApache::Control.httpd_status.should == [true, result]
  end

  it "should raise an error when calling httpd_status raising unknown result RuntimeError" do
    result = "unknown result"
    MiqUtil.stub(:runcmd).and_raise(RuntimeError.new(result))
    lambda { MiqApache::Control.httpd_status }.should raise_error(RuntimeError)
  end

  it "should runcmd with killall -9 httpd when running kill_all and cleanup file descriptors" do
    MiqUtil.should_receive(:runcmd).with("killall -9 httpd")
    MiqUtil.should_receive(:runcmd).with {|arg| arg =~ /^for i in/}
    MiqApache::Control.kill_all
  end

  it "should raise an error if killall failed with unknown result" do
    result = "unknown result"
    MiqUtil.stub(:runcmd).and_raise(RuntimeError.new(result))
    lambda { MiqApache::Control.kill_all }.should raise_error(RuntimeError)
  end

  it "should not raise an error if the kill returned no process killed" do
    result = "httpd: no process killed"
    MiqUtil.stub(:runcmd).and_raise(RuntimeError.new(result))
    lambda { MiqApache::Control.kill_all }.should_not raise_error
  end

  #FIXME: need to implement the code and change the test
  it "should not do anything when calling status with full true" do
    MiqApache::Control.should_receive(:run_apache_cmd).never
    MiqApache::Control.status(true).should be_nil
  end

  #FIXME: need to implement the code and change the test
  it "should not do anything when calling status with full false" do
    MiqApache::Control.should_receive(:run_apache_cmd).never
    MiqApache::Control.status(false).should be_nil
  end

  it "should return true with when calling config_ok? and result was 'Syntax OK'" do
    result = "Syntax OK"
    MiqUtil.stub(:runcmd).and_return(result)
    MiqApache::Control.should be_config_ok
  end

  it "should return false with when calling config_ok? and an error was raised" do
    MiqUtil.stub(:runcmd).and_raise("some error message")
    MiqApache::Control.should_not be_config_ok
  end

  it "should return false with when calling config_ok? and result was NOT 'Syntax OK'" do
    result = "Blah!"
    MiqUtil.stub(:runcmd).and_return(result)
    MiqApache::Control.should_not be_config_ok
  end

  it "should runcmd with rpm -qa... when calling version" do
    MiqUtil.should_receive(:runcmd).with {|arg| arg == "rpm -qa --queryformat '%{VERSION}' httpd" }
    MiqApache::Control.version
  end

  it "should make the apache control log's directory if missing when calling run_apache_cmd" do
    File.stub(:exists?).and_return(false)
    Dir.should_receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG))
    MiqUtil.stub(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should not make the apache control log's directory if it exists when calling run_apache_cmd" do
    File.stub(:exists?).and_return(true)
    Dir.should_receive(:mkdir).with(File.dirname(MiqApache::Control::APACHE_CONTROL_LOG)).never
    MiqUtil.stub(:runcmd)
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start" do
    cmd = "start"
    File.stub(:exists?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    $log.stub(:debug?).and_return(false)
    MiqUtil.should_receive(:runcmd).with("apachectl -E #{MiqApache::Control::APACHE_CONTROL_LOG} -k #{cmd}")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should build cmdline when calling run_apache_cmd with start in debug mode if $log is debug" do
    cmd = "start"
    File.stub(:exists?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    $log.stub(:debug?).and_return(true)
    MiqUtil.should_receive(:runcmd).with("apachectl -E #{MiqApache::Control::APACHE_CONTROL_LOG} -k #{cmd} -e debug")
    MiqApache::Control.run_apache_cmd("start")
  end

  it "should log a warning when calling run_apache_cmd with start that raises an error" do
    cmd = "start"
    File.stub(:exists?).and_return(true)
    $log = Logger.new(STDOUT) unless $log
    $log.stub(:debug?).and_return(false)
    MiqUtil.stub(:runcmd).and_raise("warn")
    $log.should_receive(:warn)
    MiqApache::Control.run_apache_cmd("start")
  end
end
