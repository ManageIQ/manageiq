if false
  require "selenium"
  require "test/unit"

  class NewTest < ActiveSupport::TestCase
    def setup
      @verification_errors = []
      if $selenium
        @selenium = $selenium
      else
        @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*firefox", "http://localhost:4444", 10000);
        @selenium.start
      end
      @selenium.set_context("test_new", "info")
    end

    def teardown
      @selenium.stop unless $selenium
      assert_equal [], @verification_errors
    end

    def test_new
      @selenium.open "/"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "//a/img"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "link=Accounts"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "//img[@alt='New-inactive']"
      @selenium.wait_for_page_to_load "30000"
      @selenium.type "name", "Erik1"
      @selenium.type "userid", "test"
      @selenium.type "password", "test"
      @selenium.type "password2", "test"
      @selenium.select "user_role", "label=User"
      @selenium.click "add"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "link=logout"
      @selenium.wait_for_page_to_load "30000"
      @selenium.type "user_name", "test"
      @selenium.type "user_password", "test"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "link=logout"
      @selenium.wait_for_page_to_load "30000"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "//a/img"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "link=Accounts"
      @selenium.wait_for_page_to_load "30000"
      @selenium.click "//tr[3]/td[1]/ul/li/img"
      assert /^Are you sure you want to delete user 'Erik1'[\s\S]$/ =~ @selenium.get_confirmation
      @selenium.click "link=logout"
      @selenium.wait_for_page_to_load "30000"
    end
  end

end
