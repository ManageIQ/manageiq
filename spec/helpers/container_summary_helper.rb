require 'set'
require "spec_helper"

describe ContainerSummaryHelper do
  REL_HASH_WITH_LINK = [:label, :image, :value, :link, :title]
  REL_HASH_WITHOUT_LINK = [:label, :image, :value]

  before do
    controller.send(:extend, ApplicationHelper)
    self.class.send(:include, ApplicationHelper)

    @record = FactoryGirl.create(
      :container_group,
      :name              => "group",
      :container_project => FactoryGirl.create(:container_project, :name => "project")
    )
    FactoryGirl.create(:container, :container_group => @record, :name => "container1")
    FactoryGirl.create(:container, :container_group => @record, :name => "container2")

    login_as @user = FactoryGirl.create(:user)
  end

  context "single relationship link allowed" do
    it 'should return linked relationship' do
      @user.stub(:role_allows?).and_return(true)

      rel_hash = textual_container_project

      rel_hash.keys.to_set.should be == REL_HASH_WITH_LINK.to_set
      rel_hash[:value].should be == "project"
    end
  end

  context "single relationship link not allowed" do
    it 'should not return linked relationship' do
      @user.stub(:role_allows?).and_return(false)

      rel_hash = textual_container_project

      rel_hash.keys.to_set.should be == REL_HASH_WITHOUT_LINK.to_set
      rel_hash[:value].should be == "project"
    end
  end

  context "multiple relationships link allowed" do
    it 'should return linked relationship' do
      @user.stub(:role_allows?).and_return(true)

      rel_hash = textual_containers

      rel_hash.keys.to_set.should be == REL_HASH_WITH_LINK.to_set
      rel_hash[:value].should be == "2"
    end
  end

  context "multiple relationships link not allowed" do
    it 'should not return linked relationship' do
      @user.stub(:role_allows?).and_return(false)

      rel_hash = textual_containers

      rel_hash.keys.to_set.should be == REL_HASH_WITHOUT_LINK.to_set
      rel_hash[:value].should be == "2"
    end
  end
end
