module Spec
  module Support
    module ServiceTemplateHelper
      def build_service_template_tree(hash)
        build_all_atomics(hash)
        build_all_composites(hash)
      end

      def get_user(options)
        options[:requester] || User.find(options[:requester_id])
      end

      def build_all_atomics(hash)
        hash.each do |name, value|
          next unless value[:type] == "atomic"

          item = FactoryBot.create(:service_template, :name         => name,
                                                       :options      => {:dialog => {}},
                                                       :service_type => 'atomic')
          item.update(:prov_type => value[:prov_type]) if value[:prov_type].present?
          next if value[:prov_type] && value[:prov_type].starts_with?("generic")
          options = value[:request]
          options ||= {}
          options[:dialog] = {}
          mprt = FactoryBot.create(:miq_provision_request_template,
                                    :requester => get_user(options),
                                    :src_vm_id => options[:src_vm_id],
                                    :options   => options)
          add_st_resource(item, mprt)
        end
      end

      def build_all_composites(hash)
        hash.each do |name, value|
          next unless value[:type] == "composite"
          next if ServiceTemplate.find_by(:name => name)
          build_a_composite(name, hash)
        end
      end

      def build_model_from_vms(items)
        model = {}
        child_options = {}
        children = []
        items.each_with_index do |item, index|
          key = "vm_service#{index + 1}"
          model[key] = add_item(item)
          children.append(key)
          child_options[key] = {:provision_index => index}
        end

        model['top'] = { :type          => 'composite',
                         :children      => children,
                         :child_options => child_options }

        build_service_template_tree(model)
      end

      def add_item(item)
        if item.respond_to?(:prov_type)
          {:type => 'atomic', :prov_type => item.prov_type}
        else
          {:type      => 'atomic',
           :prov_type => item.vendor,
           :request   => {:src_vm_id => item.id, :number_of_vms => 1, :requester => @user}
          }
        end
      end

      def build_a_composite(name, hash)
        item = FactoryBot.create(:service_template, :name         => name,
                                                     :options      => {:dialog => {}},
                                                     :service_type => 'composite')
        properties = hash[name]
        link_all_children(item, properties, hash) unless properties[:children].empty?
        item
      end

      def link_all_children(item, properties, hash)
        children = properties[:children]
        child_options = properties.key?(:child_options) ? properties[:child_options] : {}
        children.each do |name|
          child_item = ServiceTemplate.find_by(:name => name) || build_a_composite(name, hash)
          add_st_resource(item, child_item, child_options.fetch(name, {}))
        end
      end

      def add_st_resource(svc, resource, options = {})
        svc.add_resource(resource, options)
        svc.service_resources.each(&:save)
      end

      def build_service_template_request(root_st_name, user, dialog_options = {})
        root = ServiceTemplate.find_by(:name => root_st_name)
        return nil unless root
        options = {:src_id => root.id, :target_name => "barney"}.merge(dialog_options)
        FactoryBot.create(:service_template_provision_request,
                           :description    => 'Service Request',
                           :source_type    => 'ServiceTemplate',
                           :type           => 'ServiceTemplateProvisionRequest',
                           :request_type   => 'clone_to_service',
                           :approval_state => 'approved',
                           :status         => 'Ok',
                           :process        => true,
                           :request_state  => 'active',
                           :source_id      => root.id,
                           :requester      => user,
                           :options        => options)
      end

      def request_stubs
        allow(@request).to receive(:approved?).and_return(true)
        allow_any_instance_of(MiqRequestTask).to receive(:approved?).and_return(true)
        allow_any_instance_of(MiqProvision).to receive(:get_next_vm_name).and_return("fred")
        allow(@request).to receive(:automate_event_failed?).and_return(false)
      end

      def build_small_environment
        @miq_server = EvmSpecHelper.local_miq_server
        @ems = FactoryBot.create(:ems_vmware_with_authentication)
        @host1 =  FactoryBot.create(:host_vmware, :ems_id => @ems.id)
        @src_vm = FactoryBot.create(:vm_vmware, :host   => @host1,
                                                 :ems_id => @ems.id,
                                                 :name   => "barney")
      end

      def service_template_stubs
        allow(ServiceTemplate).to receive(:automate_result_include_service_template?) do |_uri, _user, name|
          @allowed_service_templates.include?(name)
        end
      end

      def user_helper
        @user = FactoryBot.create(:user_admin)
      end
    end
  end
end
