describe "CatalogBundleInitialization Automate Method" do
  include Spec::Support::ServiceTemplateHelper

  before do
    @allowed_service_templates = %w(top vm_service1 vm_service2)
    user_helper
    build_small_environment
    build_model_from_vms([@src_vm, @src_vm])
  end

  def create_request_and_tasks(dialog_options = {})
    @request = build_service_template_request("top", @user, dialog_options)
    service_template_stubs
    request_stubs
    @request.create_request_tasks
  end

  def run_automate_method
    attrs = []
    attrs << "ServiceTemplateProvisionTask::service_template_provision_task=#{@stp.id}"

    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Service/Provisioning/StateMachines&class=Methods" \
                            "&instance=CatalogBundleInitialization&" \
                            "#{attrs.join('&')}", @user)
  end

  def root_service_template_task
    @request.miq_request_tasks.detect { |y| y.miq_request_task_id.nil? }
  end

  context "override" do
    before do
      @service_name = "Fred"
      @service_description = "My Favorite Service"
      @dialog_hash = {'dialog_option_1_service_name'        => 'one',
                      'dialog_option_2_service_name'        => 'two',
                      'dialog_option_0_service_name'        => @service_name,
                      'dialog_option_0_service_description' => @service_description,
                      'dialog_tag_0_tracker'                => 'gps',
                      'dialog_tag_1_location'               => 'BOM',
                      'dialog_tag_2_location'               => 'EWR'}
      @parsed_dialog_options_hash = {1 => {:service_name => "one"},
                                     2 => {:service_name => "two"},
                                     0 => {:service_name        => @service_name,
                                           :service_description => @service_description}}
      @parsed_dialog_tags_hash = {1 => {:location => "BOM"},
                                  2 => {:location => "EWR"},
                                  0 => {:tracker => "gps"}}
    end

    def check_svc_attrs
      @stp.reload
      service = @stp.destination
      expect(service.description).to eql(@service_description)
      expect(service.name).to eql(@service_name)
      expect(service.tags[0].name).to eql('/managed/tracker/gps')
    end

    def process_stp(options)
      create_request_and_tasks
      @stp = root_service_template_task
      @stp.options = @stp.options.merge(options)
      @stp.save
      run_automate_method
    end

    it "service name and description" do
      parsed_options = {:parsed_dialog_options => @parsed_dialog_options_hash.to_yaml,
                        :parsed_dialog_tags    => @parsed_dialog_tags_hash.to_yaml}
      process_stp(parsed_options)
      check_svc_attrs
    end

    it "backward compatibility" do
      process_stp(:dialog => @dialog_hash)
      check_svc_attrs
    end

    it "allows blank dialogs" do
      expect { process_stp(:dialog => {'dialog_option_1_service_name' => ''}) }.not_to raise_exception
    end
  end
end
