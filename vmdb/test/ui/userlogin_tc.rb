if false
  #puts "$:= #{$:}"
  require "rubygems"
  require "selenium"
  require "test/unit"

  class LoginTest < ActiveSupport::TestCase
    def setup
      @verification_errors = []
      if $selenium
        @selenium = $selenium
      else
        #@selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*firefox", "http://192.168.217.130", 10000);
        @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*iexplore", "http://192.168.217.130", 10000);
        begin
          @selenium.start
        rescue
          puts "Is Selenium RC running?"
        end
      end
      @selenium.open "http://192.168.217.130"
      @selenium.set_context("info")
    end

    def teardown
      begin
        @selenium.stop unless $selenium
      rescue
        puts "Is Selenium RC running?"
      end
      assert_equal [], @verification_errors
    end

    def test_login
      @selenium.open "/"
      @selenium.type "user_name", "#{hAttributes["username"]}"
      @selenium.type "user_password", "#{hAttributes["password"]}"
      #@selenium.type "user_name", "admin"
      #@selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      if @selenium.is_text_present "failed"
        puts "#{hAttributes["username"]} or password is not valid"
        return
      end
      @selenium.click "link=logout"
      @selenium.wait_for_page_to_load "30000"
    end
  end
end
