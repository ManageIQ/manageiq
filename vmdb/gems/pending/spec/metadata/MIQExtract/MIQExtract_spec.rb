require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. metadata MIQExtract})))
require 'MIQExtract'


describe MIQExtract do

  before do
    @test_password = "v1:{acd1234567890ACEGIKzwusq/+==}"
  
    @original_log = $log
    $log = double
  end

  after do
    $log = @original_log
  end

  context "#initialize" do
    it "when passwords are masked in the log file" do

      # Some moderately realistic test data.
      test_data_with_pw = {
        "ems" => {
          "ems" => {
            :address    => "10.16.16.16",
            :hostname   => "10.16.16.16",
            :ipaddress  => "10.16.16.16",
            :username   => "Administrator",
            :password   => @test_password,
            :class_name => "EmsVmware"
          },
          "host" => {
            :address   => "10.16.16.10",
            :hostname   => "calvin.and.hobs.com",
            :ipaddress  => "10.16.16.10",
            :username   => "root",
            :password   => @test_password,
            :class_name => "HostVmwareEsx"
          },
          "connect_to"    => "host",
          :use_vim_broker => false
        },
        "snapshot" => {
          "use_existing"        => false,
          "description"         => "Test Snapshot for test",
          "create_free_percent" => 100,
          "remove_free_percent" => 100
        },
        "vmScanProfiles" => []
      }

      ost = OpenStruct.new
      ost.scanData = test_data_with_pw

      $log.should_receive(:info).with(/ems/)
      $log.should_not_receive(:info).with(/#{@test_password}/)
      expect{MIQExtract.new("/bad/file/path", ost)}.to raise_exception

    end

    it "when no password is found in the input data" do

      # Some moderately realistic test data with no passwords.
      test_data_no_pw = {
        "ems" => {
          "ems" => {
            :address    => "10.16.16.16",
            :hostname   => "10.16.16.16",
            :ipaddress  => "10.16.16.16",
            :username   => "Administrator",
            :class_name => "EmsVmware"
          },
          "host" => {
            :address    => "10.16.16.10",
            :hostname   => "calvin.and.hobs.com",
            :ipaddress  => "10.16.16.10",
            :username   => "root",
            :class_name => "HostVmwareEsx"
          },
          "connect_to" => "host",
          :use_vim_broker => false
        },
        "snapshot" => {
          "use_existing" => false,
          "description" => "Test Snapshot for test",
          "create_free_percent" => 100,
          "remove_free_percent" => 100
        },
        "vmScanProfiles" => []
      }

      ost = OpenStruct.new
      ost.scanData = test_data_no_pw

      $log.should_receive(:info).with(/ems/)
      $log.should_not_receive(:info).with(/#{@test_password}/)
      expect{MIQExtract.new("/bad/file/path", ost)}.to raise_exception

    end

    it "when one password is found in the input data and masked in the log file" do

      # Some moderately realistic test data a single password.
      test_data_connect_type_pw = {
        "ems" => {
          "ems" => {
            :address    => "10.16.16.16",
            :hostname   => "10.16.16.16",
            :ipaddress  => "10.16.16.16",
            :username   => "Administrator",
            :class_name => "EmsVmware"
          },
          "host" => {
            :address    => "10.16.16.10",
            :hostname   => "calvin.and.hobs.com",
            :ipaddress  => "10.16.16.10",
            :username   => "root",
            :password   => @test_password,
            :class_name => "HostVmwareEsx"
          },
          "connect_to" => "host",
          :use_vim_broker => false
        },
        "snapshot" => {
          "use_existing" => false,
          "description" => "Test Snapshot for test",
          "create_free_percent" => 100,
          "remove_free_percent" => 100
        },
        "vmScanProfiles" => []
      }

      ost = OpenStruct.new
      ost.scanData = test_data_connect_type_pw

      $log.should_receive(:info).with(/ems/)
      $log.should_not_receive(:info).with(/#{@test_password}/)
      expect{MIQExtract.new("/bad/file/path", ost)}.to raise_exception

    end

  end

end
