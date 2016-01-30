require 'yaml'
require_relative '../base_data'

module Openstack
  module Services
    module Orchestration
      class Data < ::Openstack::Services::BaseData
        def template
          File.open(File.join(File.dirname(File.expand_path(__FILE__)), 'test_template.yml'), "r").read
        end

        def template_loaded
          YAML.load(template)
        end

        def stack_translate_table
          {
            :stack_name => :name,
          }
        end

        def stacks
          [{
            :stack_name => "stack1",
            :template   => template,
            :parameters => {
              "key_name"      => "EmsRefreshSpec-KeyPair",
              "instance_type" => "m1.tiny",
              "image_id"      => "EmsRefreshSpec-Image",
              :__network_name => "EmsRefreshSpec-NetworkPrivate",
            }
          }, {
            :stack_name => "stack2",
            :template   => template,
            :parameters => {
              "key_name"      => "EmsRefreshSpec-KeyPair",
              "instance_type" => "m1.tiny",
              "image_id"      => "EmsRefreshSpec-Image",
              :__network_name => "EmsRefreshSpec-NetworkPrivate",
            }
          }, {
            :stack_name => "stack3",
            :template   => template,
            :parameters => {
              "key_name"      => "EmsRefreshSpec-KeyPair",
              "instance_type" => "m1.tiny",
              "image_id"      => "EmsRefreshSpec-Image",
              :__network_name => "EmsRefreshSpec-NetworkPrivate",
            }
          }]
        end

        def template_parameters
          template_loaded["parameters"]
        end

        def template_resources
          template_loaded["resources"]
        end

        def template_outputs
          template_loaded["outputs"]
        end
      end
    end
  end
end
