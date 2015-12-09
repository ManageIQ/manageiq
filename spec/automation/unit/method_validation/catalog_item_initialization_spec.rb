require "spec_helper"
include ServiceTemplateHelper

describe "CatalogItemInitialization Automate Method" do
  before(:each) do
    @allowed_service_templates = %w(top vm_service1 vm_service2)
    user_helper
    build_small_environment
    build_model
  end

  def create_request_and_tasks(dialog_options = {})
    @request = build_service_template_request("top", @user, dialog_options)
    service_template_stubs
    request_stubs
    @request.create_request_tasks
  end

  def build_model
    model = {"top"         => {:type          => 'composite',
                               :children      => %w(vm_service1 vm_service2),
                               :child_options => {'vm_service1' => {:provision_index => 0},
                                                  'vm_service2' => {:provision_index => 1}}},
             "vm_service1" => {:type    => 'atomic',
                               :request => {:src_vm_id => @src_vm.id,
                                           :number_of_vms => 1, :requester => @user}
                             },
             "vm_service2" => {:type    => 'atomic',
                               :request => {:src_vm_id => @src_vm.id,
                                           :number_of_vms => 1, :requester => @user}
                             }
            }
    build_service_template_tree(model)
  end

  def run_automate_method(stpt)
    attrs = []
    attrs << "ServiceTemplateProvisionTask::service_template_provision_task=#{stpt.id}" if stpt

    MiqAeEngine.instantiate("/System/Request/Call_Instance_With_Message?" \
                            "namespace=Service/Provisioning/StateMachines&class=Methods" \
                            "&instance=CatalogItemInitialization&" \
                            "#{attrs.join('&')}", @user)
  end

  def root_service_template_task
    @request.miq_request_tasks.detect { |y| y.miq_request_task_id.nil? }
  end

  context "options and tags" do
    it "in provision request" do
      parsed_dialog_options_hash = {1 => {:vm_target_name => "one"},
                                    2 => {:vm_target_name => "two"},
                                    0 => {:root_attr      => "fred"}}
      parsed_dialog_tags_hash = {1 => {:location => "BOM"},
                                 2 => {:location => "EWR"},
                                 0 => {:tracker  => "gps"}}

      create_request_and_tasks
      stp = root_service_template_task
      st1 = ServiceTemplate.where(:name => 'vm_service1').try(:first)
      st2 = ServiceTemplate.where(:name => 'vm_service2').try(:first)
      stp1 = stp.miq_request_tasks.detect { |x| x.source_id == st1.id }
      stp2 = stp.miq_request_tasks.detect { |x| x.source_id == st2.id }

      parsed_options = {:parsed_dialog_options => parsed_dialog_options_hash.to_yaml,
                        :parsed_dialog_tags    => parsed_dialog_tags_hash.to_yaml}
      required_options = {:vm_target_name => 'one', :root_attr => 'fred'}
      required_tags    = {:tracker => 'gps', :location => 'bom'}
      process_stp(stp1, parsed_options, required_options, required_tags)
      required_options = {:vm_target_name => 'two', :root_attr => 'fred'}
      required_tags    = {:tracker => 'gps', :location => 'ewr'}
      process_stp(stp2, parsed_options, required_options, required_tags)
    end

    def process_stp(stp, parsed_options, required_options, required_tags)
      stp.options = stp.options.merge(parsed_options)
      stp.save
      run_automate_method(stp)
      stp.reload
      check_destination_options(stp.destination, required_options)
      request_task = stp.miq_request_tasks[0].miq_request_tasks[0]
      check_vm_task(request_task, required_options, required_tags)
    end

    def check_vm_task(request_task, required_options, required_tags)
      check_options(request_task, required_options)
      check_tags(request_task, required_tags)
    end

    def check_options(request_task, required_options)
      options = request_task.options
      required_options.each { |k, v| expect(options[k]).to eql(v) }
    end

    def check_tags(request_task, required_tags)
      tags = request_task.get_tags
      required_tags.each { |k, v| expect(tags[k]).to eql(v) }
    end

    def check_destination_options(service, required_options)
      required_options.each { |k, v| expect(service.options[:dialog]["dialog_#{k}"]).to eql(v) }
    end
  end
end
