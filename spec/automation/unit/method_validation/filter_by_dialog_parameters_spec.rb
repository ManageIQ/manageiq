require "spec_helper"
include ServiceTemplateHelper

describe "FilterByDialogParameters Automate Method" do
  before do
    @allowed_service_templates = %w(top)
    user_helper
    build_small_environment
    build_model
  end

  def post_create(dialog_options = {})
    @request = build_service_template_request("top", @user, dialog_options)
    service_template_stubs
    request_stubs
    @request.create_request_tasks
  end

  def build_model
    model = {"top"        => {:type    => 'composite', :children => ['middle']},
             "middle"     => {:type    => 'composite', :children => ['vm_service']},
             "vm_service" => {:type    => 'atomic',
                              :request => {:target_name => "fred", :src_vm_id => @src_vm.id,
                                           :number_of_vms => 1, :requester => @user}
                             }
            }
    build_service_template_tree(model)
  end

  def run_automate_method(st, stpt, svc)
    attrs = []
    attrs << "ServiceTemplate::service_template=#{st.id}" if st
    attrs << "Service::service=#{svc.id}" if svc
    attrs << "ServiceTemplateProvisionTask::service_template_provision_task=#{stpt.id}" if stpt

    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Service/Provisioning&class=ServiceFilter" \
                            "&instance=FilterByDialogParameters&message=include_service&" \
                            "#{attrs.join('&')}", @user)
  end

  def root_service_template_task
    @request.miq_request_tasks.detect { |y| y.miq_request_task_id.nil? }
  end

  context "filter" do
    it "with root service" do
      post_create(:dialog => {'dialog_environment' => "should_not_care"})
      ws = run_automate_method(ServiceTemplate.find_by_name("top"),
                               root_service_template_task,
                               FactoryGirl.create(:service))
      expect(ws.root['include_service']).to be_true
    end

    it "with vm_serice" do
      post_create(:dialog => {'dialog_environment' => "vm_service"})
      ws = run_automate_method(ServiceTemplate.find_by_name("vm_service"),
                               root_service_template_task,
                               FactoryGirl.create(:service))
      expect(ws.root['include_service']).to be_true
    end

    it "with missing dialog_environment" do
      post_create(:dialog => {'dialog_fred' => "vm_service"})
      st = ServiceTemplate.find_by_name('vm_service')
      svc = FactoryGirl.create(:service)

      expect { run_automate_method(st, root_service_template_task, svc) }.to raise_exception
    end

    it "with an invalid vm_service" do
      post_create(:dialog => {'dialog_environment' => "vm_service1"})
      ws = run_automate_method(ServiceTemplate.find_by_name("vm_service"),
                               root_service_template_task,
                               FactoryGirl.create(:service))
      expect(ws.root['include_service']).to be_false
    end
  end
end
