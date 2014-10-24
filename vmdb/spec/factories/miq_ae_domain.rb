FactoryGirl.define do
  factory :miq_ae_domain_enabled, :parent => :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_domain#{seq_padded_for_sorting(n)}" }
    enabled true
  end

  factory :miq_ae_domain_disabled, :parent => :miq_ae_namespace do
    sequence(:name) { |n| "miq_ae_domain#{seq_padded_for_sorting(n)}" }
  end

  factory :miq_ae_domain, :parent => :miq_ae_namespace do
    trait :with_methods do
      ignore do
        ae_methods do {'method1' => {:scope => 'instance', :location => 'inline',
                                      'params' => {'name' => {:aetype        => 'attribute',
                                                              :datatype      => 'string',
                                                              :default_value => 'abc'},
                                                   'pass' => {:aetype        => 'attribute',
                                                              :datatype      => 'password',
                                                              :default_value => 'secret'}},
                                      :data => 'puts "Hello World"', :language => 'ruby'},
                       'method2' => {:scope => 'instance', :location => 'builtin',
                                      :language => 'ruby', 'params' => {}}}
        end
      end
    end

    trait :with_instances do
      ignore do
        ae_fields do {'field1' => {:aetype => 'state', :datatype => 'string'},
                      'field2' => {:aetype => 'relationship', :datatype => 'string'},
                      'field3' => {:aetype => 'method', :datatype => 'string'},
                      'field4' => {:aetype => 'attribute', :datatype => 'password',
                                   :default_value => 'abcd'}}
        end
        ae_instances do {'instance1' => {'field1' => {:value => 'hello world', :on_entry => 'abc'},
                                         'field2' => {:value => 'a/b/c', :collect => 'nothing'},
                                         'field3' => {:value => "puts 'simple method'"},
                                         'field4' => {:value => 'October16'}},
                         'instance2' => {'field1' => {:value => 'hello barney', :on_entry => 'abc'},
                                         'field2' => {:value => 'x/y/z', :collect => 'nothing'},
                                         'field3' => {:value => "puts 'simple method'"}}}
        end
      end
    end

    trait :with_small_model do
      ignore do
        ae_class 'CLASS1'
        ae_namespace 'NS1/NS2'
      end

      after :create do |aedomain, evaluator|
        args = {}
        args[:name] = evaluator.ae_class if evaluator.respond_to?('ae_class')
        args[:namespace] = "#{aedomain.name}/#{evaluator.ae_namespace}" if evaluator.respond_to?('ae_namespace')
        items = %w(ae_fields ae_instances ae_methods)
        items.each { |f| args[f] = evaluator.respond_to?(f) ? evaluator.send(f) : {} }

        FactoryGirl.create(:miq_ae_class, :with_instances_and_methods, args) if evaluator.respond_to?('ae_class')
      end
    end
  end

end
