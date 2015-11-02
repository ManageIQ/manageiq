require 'spec_helper'
include AutomationSpecHelper

describe MiqAeMethodService::MiqAeServiceClassification do
  before do
    @cat1 = FactoryGirl.create(:classification_department_with_tags)
    @cat2 = FactoryGirl.create(:classification_cost_center_with_tags)
    @cat_array = Classification.categories.collect(&:name)
    @tags_array = @cat2.entries.collect(&:name)
  end

  let(:user) { FactoryGirl.create(:user_with_group) }

  def setup_model(method_script)
    create_ae_model_with_method(:method_script => method_script,
                                :name          => 'VITALSTATISTIX',
                                :ae_namespace  => 'OBELIX',
                                :ae_class      => 'ASTERIX',
                                :instance_name => 'DOGMATIX',
                                :method_name   => 'GETAFIX')
  end

  def invoke_ae
    MiqAeEngine.instantiate("/OBELIX/ASTERIX/DOGMATIX", user)
  end

  it "get a list of categories" do
    setup_model("$evm.root['result'] = $evm.vmdb('Classification').categories")
    cats = invoke_ae.root('result')
    expect(cats.collect(&:name)).to match_array(@cat_array)
  end

  it "check the tags" do
    script = <<-'RUBY'
      categories = $evm.vmdb('Classification').categories
      cc = categories.detect { |c| c.name == 'cc' }
      $evm.root['result'] = cc.entries
    RUBY
    setup_model(script)
    tags = invoke_ae.root('result')
    expect(tags.collect(&:name)).to match_array(@tags_array)
  end
end
