require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
require 'miqservices_controller'

class MiqServicesController; def rescue_action(e) raise e end; end

class MiqServicesControllerApiTest < ActiveSupport::TestCase
  def setup
    @controller = MiqServicesController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_register_vm
    # result = invoke :register_vm, "uri:test_vm"
    # assert_equal 22, result
  end

  def test_save_vm_metadata
    # result = invoke :save_vm_metadata, 22, "<someXML/>"
    # assert_equal true, result
  end
end
