module ServiceTemplateHelper
  def build_service_template_tree(hash)
    build_all_atomics(hash)
    build_all_composites(hash)
  end

  def build_all_atomics(hash)
    hash.each do |name, value|
      next unless value[:type] == "atomic"
      item  = FactoryGirl.create(:service_template, :name         => name,
                                                    :service_type => 'atomic')
      options = value[:request]
      mprt = FactoryGirl.create(:miq_provision_request_template,
                                :requester => options[:requester],
                                :src_vm_id => options[:src_vm_id],
                                :options   => options)
      add_st_resource(item, mprt)
    end
  end

  def build_all_composites(hash)
    hash.each do |name, value|
      next unless value[:type] == "composite"
      next if ServiceTemplate.find_by_name(name)
      build_a_composite(name, hash)
    end
  end

  def build_a_composite(name, hash)
    item  = FactoryGirl.create(:service_template, :name         => name,
                                                  :service_type => 'composite')
    properties = hash[name]
    link_all_children(item, properties, hash) unless properties[:children].empty?
    item
  end

  def link_all_children(item, properties, hash)
    children = properties[:children]
    child_options = properties.key?(:child_options) ? properties[:child_options] : {}
    children.each do |name|
      child_item = ServiceTemplate.find_by_name(name) || build_a_composite(name, hash)
      add_st_resource(item, child_item, child_options.fetch(name, {}))
    end
  end

  def add_st_resource(svc, resource, options = {})
    svc.add_resource(resource, options)
    svc.service_resources.each(&:save)
  end

  def build_service_template_request(root_st_name, user, dialog_options = {})
    root = ServiceTemplate.find_by_name(root_st_name)
    return nil unless root
    options = {:src_id => root.id, :target_name => "barney"}.merge(dialog_options)
    FactoryGirl.create(:service_template_provision_request,
                       :description    => 'Service Request',
                       :source_type    => 'ServiceTemplate',
                       :type           => 'ServiceTemplateProvisionRequest',
                       :request_type   => 'clone_to_service',
                       :approval_state => 'approved',
                       :source_id      => root.id,
                       :requester      => user,
                       :options        => options)
  end

  def request_stubs
    @request.stub(:approved?).and_return(true)
    MiqRequestTask.any_instance.stub(:approved?).and_return(true)
    MiqProvision.any_instance.stub(:get_next_vm_name).and_return("fred")
    @request.stub(:automate_event_failed?).and_return(false)
  end

  def build_small_environment
    @miq_server = EvmSpecHelper.local_miq_server
    @ems = FactoryGirl.create(:ems_vmware_with_authentication)
    @host1 =  FactoryGirl.create(:host_vmware, :ems_id => @ems.id)
    @src_vm = FactoryGirl.create(:vm_vmware, :host   => @host1,
                                             :ems_id => @ems.id,
                                             :name   => "barney")
  end

  def service_template_stubs
    ServiceTemplate.stub(:automate_result_include_service_template?) do |_uri, _user, name|
      @allowed_service_templates.include?(name)
    end
  end

  def user_helper
    User.any_instance.stub(:role).and_return("admin")
    @user = FactoryGirl.create(:user_with_group, :name => 'Wilma', :userid => 'wilma')
  end
end
