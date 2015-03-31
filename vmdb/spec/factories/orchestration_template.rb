FactoryGirl.define do
  factory :orchestration_template do
    sequence(:name)        { |n| "template name #{seq_padded_for_sorting(n)}" }
    sequence(:content)     { |n| "any template text #{seq_padded_for_sorting(n)}" }
    sequence(:description) { |n| "some description #{seq_padded_for_sorting(n)}" }
  end

  factory :orchestration_template_cfn, :parent => :orchestration_template, :class => OrchestrationTemplateCfn do
    sequence(:content)     { |n| "{\"AWSTemplateFormatVersion\" : \"version(#{seq_padded_for_sorting(n)})\"}" }
  end

  factory :orchestration_template_with_stacks, :parent => :orchestration_template do
    stacks { [FactoryGirl.create(:orchestration_stack)] }
  end

  factory :orchestration_template_cfn_with_stacks, :parent => :orchestration_template_cfn do
    stacks { [FactoryGirl.create(:orchestration_stack)] }
  end

  factory :orchestration_template_with_content, :parent => :orchestration_template do
    type 'OrchestrationTemplateCfn'
    content '{'\
            '"Description" : "Description",'\
            '"Parameters" : {'\
            '    "KeyName" : {'\
            '      "Description" : "Description",'\
            '      "Type" : "String",'\
            '      "Default": "Description"'\
            '}}}'
  end
end
