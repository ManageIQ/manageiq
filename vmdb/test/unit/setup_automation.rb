$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

if false
  require 'selenium'
  require 'test/unit'
  #require "erb"

  class SetupAutomation < ActiveSupport::TestCase

    def setup
      @configs = YAML::load(ERB.new(IO.read(File.join(File.dirname(__FILE__), "./configuration/auto_configs.yml"))).result)
      @verification_errors = []
      if $selenium
        @selenium = $selenium
      else
        #Starts firefox or ie
        if @configs[:browser][:ie]
          @selenium = Selenium::SeleniumDriver.new("localhost", 4444, "*iehta", @configs[:server][:address], 10000)
        else
          @selenium = Selenium::SeleniumDriver.new("localhost", 4444, "*chrome", @configs[:server][:address], 10000)
        end
        #      @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*firefox", @configs[:server][:address], 10000);
        #      @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*custom C:/Program Files (x86)/Safari/Safari.exe", @configs[:server][:address], 10000);
        #      @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*iexplore", @configs[:server][:address], 10000);
        @selenium.start
      end
      @selenium.set_context("info")
    end

    def test_setup
      begin
        #Open main page
        @selenium.open @configs[:server][:address]
      rescue Exception => err
        File.open("C:/work/test.log", "a") do |f|
          f.puts "error: #{err.to_s}"
          f.puts "backtrace: #{err.backtrace.join("\n")}"
        end
        raise
      end
      #Login with a set username/password
      @selenium.type "user_name", @configs[:server][:username]
      @selenium.type "user_password", @configs[:server][:password]
      @selenium.click "login"
      @selenium.wait_for_page_to_load "60000"
      #If it's our first time logging into this appliance, it needs a
      #license file, so this if will catch that and upload the license file
      #that is stored in the config file
      if (@selenium.is_element_present("upload_file"))
        @selenium.type "upload_file", @configs[:server][:licenseloc]
        @selenium.click "commit"
        @selenium.wait_for_page_to_load "60000"
      end
      #Next, go to the operations config page
      @selenium.open @configs[:server][:address] + "/configuration"
      @selenium.wait_for_page_to_load "60000"
      @selenium.open @configs[:server][:address] + "/configuration/index?config_tab=operations"
      @selenium.wait_for_page_to_load "60000"
      #Set the logging level to debug by default
      @selenium.select "log_level", @configs[:settings][:loglevel]
      #Set the timeout to 24 hours, 55 minutes
      @selenium.select "session_timeout_hours", @configs[:settings][:timeouthours]
      @selenium.select "session_timeout_mins", @configs[:settings][:timeoutminutes]
      @selenium.click "save"
      @selenium.wait_for_page_to_load "60000"
      #Go to the SmartProxy page
      @selenium.open @configs[:server][:address] + "/configuration"
      @selenium.wait_for_page_to_load "60000"
      @selenium.open @configs[:server][:address] + "/miq_proxy_build/index"
      @selenium.wait_for_page_to_load "60000"
      #Set the log level again, and the wrap time
      @selenium.select "agent_log_level", @configs[:settings][:loglevel]
      @selenium.select "agent_log_wraptime_days", @configs[:settings][:wraptime]
      @selenium.click "save"
      @selenium.wait_for_page_to_load "60000"
      #Go to the Management Systems page and click the discover button
      @selenium.open @configs[:server][:address] + "/management_system/show_list"
      @selenium.wait_for_page_to_load "60000"
      @selenium.click "//img[@alt='Discover Management Systems']"
      @selenium.wait_for_page_to_load "60000"
      #Discover the EMS by IP address given in the config file
      @selenium.type "from_first", @configs[:ems][:discovery][:firstip]
      @selenium.type "from_second", @configs[:ems][:discovery][:secondip]
      @selenium.type "from_third", @configs[:ems][:discovery][:thirdip]
      @selenium.type "from_fourth", @configs[:ems][:discovery][:fourthip]
      @selenium.type "to_fourth", @configs[:ems][:discovery][:fourthtoip]
      @selenium.click "cat_cb"
      @selenium.click "start"
      @selenium.wait_for_page_to_load "60000"
      test = ExtManagementSystem.find(:all)
      #Since it takes time to discover the EMSs, we test every 30 seconds to see
      #if the list has been updated.
      until test[0] != nil
        @selenium.refresh
        sleep(30)
        test = ExtManagementSystem.find(:all)
      end
      testems = test[0]
      @selenium.open @configs[:server][:address] + "/management_system"
      @selenium.wait_for_page_to_load "60000"
      @selenium.open @configs[:server][:address] + "/management_system/show/" + testems.id.to_s
      @selenium.wait_for_page_to_load "60000"
      @selenium.open @configs[:server][:address] + "/management_system/edit/" + testems.id.to_s
      @selenium.wait_for_page_to_load "60000"
      #Navigate to the EMS and validate its credentials
      @selenium.type "userid", @configs[:ems][:username]
      @selenium.type "password", @configs[:ems][:password]
      @selenium.type "verify", @configs[:ems][:password]
      @selenium.click "validate"
      #This is effectively "waiting" for the validation to be complete by continually testing to see
      #if a message has popped up yet.  Either "Unexpected response" or "validation was successful"
      assert !100.times{ break if (@selenium.is_text_present("Unexpected response") || @selenium.is_text_present("validation was successful") rescue false); sleep 5 }
      #If there was an unexpected response, print out that there was
      if (@selenium.is_text_present("Unexpected response"))
        puts "Invalid credentials for EMS: " + testems.name
        # For right now, I'm leaving this commented out because I want the
        # test to be fully automated and not have someone be watching it waiting
        # for the validation to fail.  If the validation fails, something in the
        # config file is incorrect and should be changed, or the EMS could not
        # be reached (timeout).
        #        puts "Username: "
        #        ems_username = gets.chomp
        #        puts "Password: "
        #        ems_password = gets.chomp
        #        @selenium.open @configs[:server][:address] + "/management_system/show/" + test.id.to_s
        #        @selenium.wait_for_page_to_load "60000"
        #        @selenium.open @configs[:server][:address] + "/management_system/edit/" + test.id.to_s
        #        @selenium.type "userid", ems_username
        #        @selenium.type "password", ems_password
        #        @selenium.type "verify", ems_password
        #        @selenium.click "validate"
      end
      #If it was successful, we need to start the refresh of the Hosts/VMs
      if (@selenium.is_text_present("validation was successful"))
        @selenium.click "save"
        @selenium.wait_for_page_to_load "60000"
        @selenium.click "nav_refresh_img"
        #This hits "ok" on the popup
        assert /^Refresh relationships and power states for all items related to this Management System[\s\S]$/ =~ @selenium.get_confirmation
        assert !60.times{ break if (@selenium.is_text_present("'refresh_ems' successfully initiated") rescue false); sleep 5}
      end
      @selenium.open "/host/show_list"
      test = Host.find(:all)
      #Since it takes some time to load the Hosts, we wait until they
      #are all in the list, and then put that list in test
      while (test[@configs[:host][:numhosts] - 1] == nil)
        @selenium.refresh
        sleep(30)
        test = Host.find(:all)
      end
      #Go through all of the hosts and validate them one by one.
      for i in test
        testhost = i
        #      testhost = test[]
        @selenium.open @configs[:server][:address] + "/host/edit/" + testhost.id.to_s
        #      puts testhost.id.to_s
        @selenium.wait_for_page_to_load "60000"
        @selenium.type "userid", @configs[:host][:username]
        @selenium.type "password", @configs[:host][:password]
        @selenium.type "verify", @configs[:host][:password]
        @selenium.click "validate"
        assert !100.times{ break if (@selenium.is_text_present("Unexpected response") || @selenium.is_text_present("validation was successful") rescue false); sleep 5 }
        if @selenium.is_text_present("Unexpected response")
          puts "Invalid credentials or server timeout for host: " + testhost.name
        end
        if @selenium.is_text_present("validation was successful")
          @selenium.click "save"
        end
      end
    end

    def teardown
      @selenium.stop unless $selenium
      assert_equal [], @verification_errors
    end

  end

end
