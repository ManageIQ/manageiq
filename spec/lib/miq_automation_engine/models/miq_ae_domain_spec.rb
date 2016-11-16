describe MiqAeDomain do
  before do
    EvmSpecHelper.local_guid_miq_server_zone
    @user = FactoryGirl.create(:user_with_group)
  end

  it "should use the highest priority when not specified" do
    FactoryGirl.create(:miq_ae_domain, :name => 'TEST1')
    FactoryGirl.create(:miq_ae_domain, :name => 'TEST2', :priority => 10)
    d3 = FactoryGirl.create(:miq_ae_domain, :name => 'TEST3')
    expect(d3.priority).to eql(11)
  end

  context "reset priority" do
    before do
      initial = {'TEST1' => 11, 'TEST2' => 12, 'TEST3' => 13, 'TEST4' => 14}
      initial.each { |dom, pri| FactoryGirl.create(:miq_ae_domain, :name => dom, :priority => pri) }
    end

    it "should change priority based on ordered list of ids" do
      after = {'TEST4' => 1, 'TEST3' => 2, 'TEST2' => 3, 'TEST1' => 4}
      ids   = after.collect { |dom, _| MiqAeDomain.find_by_fqname(dom).id }
      MiqAeDomain.reset_priority_by_ordered_ids(ids)
      after.each { |dom, pri| expect(MiqAeDomain.find_by_fqname(dom).priority).to eql(pri) }
    end

    it "after a domain with lowest priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST1').id)
      after = {'TEST2' => 1, 'TEST3' => 2, 'TEST4' => 3}
      after.each { |dom, pri| expect(MiqAeDomain.find_by_fqname(dom).priority).to eql(pri) }
    end

    it "after a domain with middle priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST3').id)
      after = {'TEST1' => 1, 'TEST2' => 2, 'TEST4' => 3}
      after.each { |dom, pri| expect(MiqAeDomain.find_by_fqname(dom).priority).to eql(pri) }
    end

    it "after a domain with highest priority is deleted" do
      MiqAeDomain.destroy(MiqAeDomain.find_by_fqname('TEST4').id)
      after = {'TEST1' => 1, 'TEST2' => 2, 'TEST3' => 3}
      after.each { |dom, pri| expect(MiqAeDomain.find_by_fqname(dom).priority).to eql(pri) }
    end

    it "after all domains are deleted" do
      %w(TEST1 TEST2 TEST3 TEST4).each { |name| MiqAeDomain.find_by_fqname(name).destroy }
      d1 = FactoryGirl.create(:miq_ae_domain, :name => 'TEST1')
      expect(d1.priority).to eql(1)
    end
  end

  context "any_unlocked?" do
    it "should return unlocked_domains? as true if the there are any unlocked domains available" do
      FactoryGirl.create(:miq_ae_system_domain)
      FactoryGirl.create(:miq_ae_domain)
      expect(MiqAeDomain.any_unlocked?).to be_truthy
    end

    it "should return unlocked_domains? as false if the there are no unlocked domains available" do
      FactoryGirl.create(:miq_ae_system_domain)
      FactoryGirl.create(:miq_ae_system_domain)
      expect(MiqAeDomain.any_unlocked?).to be_falsey
    end
  end

  context "all_unlocked" do
    it "should return all unlocked domains" do
      FactoryGirl.create(:miq_ae_system_domain)
      FactoryGirl.create(:miq_ae_domain)
      FactoryGirl.create(:miq_ae_domain)
      expect(MiqAeDomain.all_unlocked.count).to eq(2)
    end

    it "should return empty array when there are no unlocked domains" do
      FactoryGirl.create(:miq_ae_system_domain)
      FactoryGirl.create(:miq_ae_system_domain)
      FactoryGirl.create(:miq_ae_system_domain)
      expect(MiqAeDomain.all_unlocked.count).to eq(0)
    end
  end

  context "same class names across domains" do
    before(:each) do
      create_model(:name => 'DOM1', :priority => 10)
    end

    it "missing class should get empty array" do
      result = MiqAeClass.get_homonymic_across_domains(@user, 'DOM1/CLASS1')
      expect(result).to be_empty
    end

    it "get same named classes" do
      create_multiple_domains
      expected = %w(/DOM2/A/b/C/cLaSS1 /DOM1/A/B/C/CLASS1 /DOM3/a/B/c/CLASs1)
      result = MiqAeClass.get_homonymic_across_domains(@user, '/DOM1/A/B/C/CLASS1', true)
      expect(expected).to match_string_array_ignorecase(result.collect(&:fqname))
    end
  end

  context "same instance names across domains" do
    before(:each) do
      create_model(:name => 'DOM1', :priority => 10)
    end

    it "missing instance should get empty array" do
      result = MiqAeInstance.get_homonymic_across_domains(@user, 'DOM1/CLASS1/nothing')
      expect(result).to be_empty
    end

    it "get same named instances" do
      create_multiple_domains
      expected = %w(
        /DOM5/A/B/C/CLASS1/instance1
        /DOM2/A/b/C/cLaSS1/instance1
        /DOM1/A/B/C/CLASS1/instance1
        /DOM3/a/B/c/CLASs1/instance1
      )
      result = MiqAeInstance.get_homonymic_across_domains(@user, '/DOM1/A/B/C/CLASS1/instance1')
      expect(expected).to match_string_array_ignorecase(result.collect(&:fqname))
    end
  end

  context "same method names across domains" do
    before(:each) do
      create_model_with_methods(:name => 'DOM1', :priority => 10)
    end

    it "missing method should get empty array" do
      result = MiqAeMethod.get_homonymic_across_domains(@user, 'DOM1/CLASS1/nothing')
      expect(result).to be_empty
    end

    it "get same named methods" do
      create_multiple_domains_with_methods
      expected = %w(/DOM2/A/b/C/cLaSS1/method1 /DOM1/A/B/C/CLASS1/method1 /DOM3/a/B/c/CLASs1/method1)
      result = MiqAeMethod.get_homonymic_across_domains(@user, '/DOM1/A/B/C/CLASS1/method1', true)
      expect(expected).to match_string_array_ignorecase(result.collect(&:fqname))
    end
  end

  context "editable properties for a domain" do
    it "manageiq domain can't change properties" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :name => "ManageIQ", :tenant => @user.current_tenant)
      expect(dom.editable_properties?).to be_falsey
    end

    it "user domain can change properties" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.editable_properties?).to be_truthy
    end

    it "git domain cannot change properties" do
      dom = FactoryGirl.create(:miq_ae_git_domain, :tenant => @user.current_tenant)
      expect(dom.editable_properties?).to be_truthy
    end
  end

  context "lock contents" do
    it "contents_locked? should be false for user domain" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.contents_locked?).to be_falsey
    end

    it "contents_locked? should be true for user domain after its locked" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      dom.lock_contents!
      expect(dom.contents_locked?).to be_truthy
    end

    it "call lock_contents! multiple times" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      dom.lock_contents!
      dom.lock_contents!
      expect(dom.contents_locked?).to be_truthy
    end

    it "contents_locked? should be true for user domain" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
      expect(dom.contents_locked?).to be_truthy
    end

    it "cannot lock a system domain" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
      expect { dom.lock_contents! }.to raise_error(MiqAeException::CannotLock)
    end
  end

  context "unlock contents" do
    it "cannot unlock a system domain" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
      expect { dom.unlock_contents! }.to raise_error(MiqAeException::CannotUnlock)
    end

    it "call unlock_contents! multiple times" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      dom.lock_contents!
      dom.unlock_contents!
      dom.unlock_contents!
      expect(dom.contents_locked?).to be_falsey
    end
  end

  context "editable contents for a domain" do
    it "system domain can't change contents" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
      expect(dom.editable_contents?(@user)).to be_falsey
    end

    it "user domain can change contents" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.editable_contents?(@user)).to be_truthy
    end

    it "git domain cannot change contents" do
      dom = FactoryGirl.create(:miq_ae_git_domain, :tenant => @user.current_tenant)
      expect(dom.editable_contents?(@user)).to be_falsey
    end
  end

  context "lockable" do
    it "a user domain should be lockable" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.lockable?).to be_truthy
    end

    it "a locked user domain should not be lockable" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      dom.lock_contents!
      expect(dom.lockable?).to be_falsey
    end
  end

  context "unlockable" do
    it "a locked user domain should be unlockable" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      dom.lock_contents!
      expect(dom.unlockable?).to be_truthy
    end

    it "a unlocked user domain should not be unlockable" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.unlockable?).to be_falsey
    end
  end

  context "editable property" do
    it "system domain" do
      dom = FactoryGirl.create(:miq_ae_system_domain, :tenant => @user.current_tenant)
      expect(dom.editable_property?('name')).to be_falsey
      expect(dom.editable_property?('description')).to be_falsey
      expect(dom.editable_property?('priority')).to be_falsey
      expect(dom.editable_property?('enabled')).to be_falsey
    end

    it "git domain" do
      dom = FactoryGirl.create(:miq_ae_git_domain, :tenant => @user.current_tenant)
      expect(dom.editable_property?(:name)).to be_falsey
      expect(dom.editable_property?(:description)).to be_falsey
      expect(dom.editable_property?('priority')).to be_truthy
      expect(dom.editable_property?('enabled')).to be_truthy
    end

    it "user domain" do
      dom = FactoryGirl.create(:miq_ae_domain, :tenant => @user.current_tenant)
      expect(dom.editable_property?(:name)).to be_truthy
      expect(dom.editable_property?(:description)).to be_truthy
      expect(dom.editable_property?('priority')).to be_truthy
      expect(dom.editable_property?('enabled')).to be_truthy
    end
  end

  context "reset priority" do
    it "#reset_priorites" do
      FactoryGirl.create(:miq_ae_system_domain, :name => 'ManageIQ', :tenant => @user.current_tenant, :priority => 0)
      FactoryGirl.create(:miq_ae_system_domain, :name => 'B', :tenant => @user.current_tenant)
      FactoryGirl.create(:miq_ae_system_domain, :name => 'A', :tenant => @user.current_tenant)
      FactoryGirl.create(:miq_ae_system_domain, :name => 'Z', :tenant => @user.current_tenant)
      FactoryGirl.create(:miq_ae_domain, :name => 'U1', :tenant => @user.current_tenant)
      FactoryGirl.create(:miq_ae_domain, :name => 'U2', :tenant => @user.current_tenant)

      ordered_names = %w(ManageIQ Z B A U1 U2)
      MiqAeDomain.reset_priorities
      expect(MiqAeDomain.all.order('priority').collect(&:name)).to eq(ordered_names)
    end
  end

  context "git enabled domains" do
    let(:commit_time) { Time.now.utc }
    let(:commit_time_new) { Time.now.utc + 1.hour }
    let(:commit_message) { "R2D2" }
    let(:commit_sha) { "abcd" }
    let(:branch_name) { "b1" }
    let(:tag_name) { "t1" }
    let(:domain_name) { "BB8" }
    let(:url) { "http://www.example.com/x/y" }
    let(:dom1) do
      FactoryGirl.create(:miq_ae_git_domain,
                         :tenant => @user.current_tenant,
                         :name   => domain_name)
    end
    let(:dom2) { FactoryGirl.create(:miq_ae_domain) }
    let(:repo) { FactoryGirl.create(:git_repository, :url => url) }
    let(:git_import) { instance_double('MiqAeYamlImportGitfs') }
    let(:info) { {'commit_time' => commit_time, 'commit_message' => commit_message, 'commit_sha' => commit_sha} }
    let(:new_info) { {'commit_time' => commit_time_new, 'commit_message' => "BB-8", 'commit_sha' => "def"} }
    let(:commit_hash) do
      {'commit_message' => commit_message, 'commit_time' => commit_time,
       'commit_sha' => commit_sha, 'ref' => branch_name, 'ref_type' => MiqAeGitImport::BRANCH}
    end
    let(:branch) { FactoryGirl.create(:git_branch, :name => branch_name) }
    let(:tag) { FactoryGirl.create(:git_tag, :name => tag_name) }

    it "check if a git domain is locked" do
      expect(dom1.editable?(@user)).to be_falsey
      expect(dom1.git_enabled?).to be_truthy
    end

    it "a regular domain should not be git enabled" do
      expect(dom2.git_enabled?).to be_falsey
    end

    it "git info" do
      expect(repo).to receive(:branch_info).with(branch_name).and_return(info)

      dom1.update_git_info(repo, branch_name, MiqAeGitImport::BRANCH)
      dom1.reload
      expect(dom1.attributes).to have_attributes(commit_hash)
    end

    it "git repo changed for non git domain" do
      expect { dom2.git_repo_changed? }.to raise_error(MiqAeException::InvalidDomain)
    end

    it "git repo branch changed" do
      expect_any_instance_of(GitRepository).to receive(:branch_info).with(branch_name).twice.and_return(new_info)
      dom1.update_attributes(:ref => branch_name, :git_repository => repo,
                             :ref_type => MiqAeGitImport::BRANCH, :commit_sha => commit_sha)
      expect(dom1.git_repo_changed?).to be_truthy
      expect(dom1.latest_ref_info).to have_attributes(new_info)
    end

    it "git repo tag changed" do
      expect(repo).to receive(:tag_info).with(tag_name).twice.and_return(new_info)
      dom1.update_attributes(:ref => tag_name, :ref_type => MiqAeGitImport::TAG,
                             :git_repository => repo, :commit_sha => commit_sha)
      expect(dom1.git_repo_changed?).to be_truthy
      expect(dom1.latest_ref_info).to have_attributes(new_info)
    end

    it "git repo tag changed with no branch or tag" do
      dom1.update_attributes(:git_repository => repo, :commit_sha => commit_sha)

      expect { dom1.git_repo_changed? }.to raise_error(RuntimeError)
    end
  end

  def create_model(attrs = {})
    attrs = default_attributes(attrs)
    ae_fields = {'field1' => {:aetype => 'relationship', :datatype => 'string'}}
    ae_instances = {'instance1' => {'field1' => {:value => 'hello world'}}}

    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_instances,
                       attrs.merge('ae_fields' => ae_fields, 'ae_instances' => ae_instances))
  end

  def create_model_with_methods(attrs = {})
    attrs = default_attributes(attrs)
    ae_methods = {'method1' => {:scope => 'instance', :location => 'inline',
                                :data => 'puts "Hello World"',
                                :language => 'ruby', 'params' => {}}}
    FactoryGirl.create(:miq_ae_domain, :with_small_model, :with_methods,
                       attrs.merge('ae_methods' => ae_methods))
  end

  def create_multiple_domains
    create_model(:name => 'DOM2', :priority => 20, :ae_class => 'cLaSS1',
                 :ae_namespace => 'A/b/C')
    create_model(:name => 'DOM3', :priority => 5, :ae_class => 'CLASs1',
                 :ae_namespace => 'a/B/c')
    create_model(:name => 'DOM4', :priority => 2, :ae_class => 'CLASs1',
                 :ae_namespace => 'a/B')
    create_model(:name => 'DOM5', :priority => 50, :enabled => false)
  end

  def create_multiple_domains_with_methods
    create_model_with_methods(:name => 'DOM2', :priority => 20, :ae_class => 'cLaSS1',
                              :ae_namespace => 'A/b/C')
    create_model_with_methods(:name => 'DOM3', :priority => 5, :ae_class => 'CLASs1',
                              :ae_namespace => 'a/B/c')
    create_model_with_methods(:name => 'DOM4', :priority => 2, :ae_class => 'CLASs1',
                              :ae_namespace => 'a/B')
    create_model_with_methods(:name => 'DOM5', :priority => 50, :enabled => false)
  end

  def default_attributes(attrs = {})
    attrs[:ae_class] = 'CLASS1' unless attrs.key?(:ae_class)
    attrs[:ae_namespace] = 'A/B/C' unless attrs.key?(:ae_namespace)
    attrs[:priority] = 10 unless attrs.key?(:priority)
    attrs[:enabled] = true unless attrs.key?(:enabled)
    attrs
  end

  describe "#display_name" do
    context "when the domain is git enabled" do
      let(:domain) do
        described_class.new(
          :name           => "Domain name",
          :git_repository => git_repository,
          :ref            => "branch1",
          :ref_type       => "branch"
        )
      end

      let(:git_repository) { GitRepository.new }

      it "returns the domain name with the current ref name" do
        expect(domain.display_name).to eq("Domain name (branch1)")
      end
    end

    context "when the domain is not git enabled" do
      let(:domain) { described_class.new(:display_name => "potato", :git_repository => git_repository) }
      let(:git_repository) { nil }

      it "returns the display name" do
        expect(domain.display_name).to eq("potato")
      end
    end
  end

  describe "#destroy_via_queue" do
    shared_context "domain_context" do
      let(:user) { FactoryGirl.create(:user_with_group) }
      let(:task) { FactoryGirl.create(:miq_task) }
      let(:task_options) { {:action => "Destroy domain", :userid => user.userid} }
      let(:queue_options) do
        {
          :class_name  => "MiqAeDomain",
          :instance_id => domain.id,
          :method_name => "destroy",
          :role        => role,
          :args        => []
        }
      end
    end

    shared_examples_for "create queue entry" do
      it "valid queue entry" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options).and_return(task.id)
        expect(domain.destroy_via_queue(user)).to eq(task.id)
      end
    end

    context "git enabled domain" do
      include_context "domain_context"
      let(:domain) { FactoryGirl.create(:miq_ae_git_domain) }
      let(:role) { "git_owner" }

      it_behaves_like "create queue entry"
    end

    context "regular domain" do
      include_context "domain_context"
      let(:domain) { FactoryGirl.create(:miq_ae_domain) }
      let(:role) { nil }

      it_behaves_like "create queue entry"
    end

    context "raises error if user not provided" do
      let(:domain) { FactoryGirl.create(:miq_ae_domain) }
      it "raise ArgumentError" do
        expect { domain.destroy(nil) }.to raise_exception(ArgumentError)
      end
    end
  end
end
