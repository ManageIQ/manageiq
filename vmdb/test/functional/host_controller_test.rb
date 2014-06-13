if false

  require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
  require 'host_controller'

  # Re-raise errors caught by the controller.
  class HostController; def rescue_action(e) raise e end; end

  class HostControllerTest < ActiveSupport::TestCase
    fixtures :hosts

    def setup
      @controller = HostController.new
      @request    = ActionController::TestRequest.new
      @response   = ActionController::TestResponse.new
    end

    def test_index
      get :index
      assert_response :success
      assert_template 'list'
    end

    def test_list
      get :list

      assert_response :success
      assert_template 'list'

      assert_not_nil assigns(:hosts)
    end

    def test_show
      get :show, :id => 1

      assert_response :success
      assert_template 'show'

      assert_not_nil assigns(:host)
      assert assigns(:host).valid?
    end

    def test_new
      get :new

      assert_response :success
      assert_template 'new'

      assert_not_nil assigns(:host)
    end

    def test_create
      num_hosts = Host.count

      post :create, :host => {}

      assert_response :redirect
      assert_redirected_to :action => 'list'

      assert_equal num_hosts + 1, Host.count
    end

    def test_edit
      get :edit, :id => 1

      assert_response :success
      assert_template 'edit'

      assert_not_nil assigns(:host)
      assert assigns(:host).valid?
    end

    def test_update
      post :update, :id => 1
      assert_response :redirect
      assert_redirected_to :action => 'show', :id => 1
    end

    def test_destroy
      assert_not_nil Host.find(1)

      post :destroy, :id => 1
      assert_response :redirect
      assert_redirected_to :action => 'list'

      assert_raise(ActiveRecord::RecordNotFound) {
        Host.find(1)
      }
    end
  end

end
