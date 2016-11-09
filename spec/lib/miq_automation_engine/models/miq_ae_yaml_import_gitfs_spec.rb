describe MiqAeYamlImportGitfs do
  before do
    @git_db = "TestGit.git"
    @ae_db_dir = Dir.mktmpdir
    @default_hash = {:a => "one", :b => "two", :c => "three"}
    @dirnames = %w(A B c)
    @namespaces = %w(NS1 NS2)
    @classes    = %w(CLASS1 CLASS2)
    @instances  = %w(INSTANCE1 INSTANCE2)
    @methods    = %w(METHOD1 METHOD2 METHOD3)
  end

  def build_git_repository(domain_name, domain_dir)
    @domain = domain_name
    @domain_dir = domain_dir
    @domain_file = if domain_dir
                     "#{domain_dir}/#{MiqAeYamlImportExportMixin::DOMAIN_YAML_FILENAME}"
                   else
                     MiqAeYamlImportExportMixin::DOMAIN_YAML_FILENAME
                   end
    @repo_path = File.join(@ae_db_dir, @git_db)
    @repo_options = {:path     => @repo_path,
                     :username => "user1",
                     :email    => "user1@example.com",
                     :bare     => true,
                     :new      => true}
    @ae_db = GitWorktree.new(@repo_options)
    add_files_to_repo
  end

  def add_files_to_repo
    add_file(@domain_file)
    @namespaces.each { |ns| add_namespace(ns) }
    @ae_db.send(:commit, "files_added").tap { |cid| @ae_db.send(:merge, cid) }
  end

  def add_file(f)
    @ae_db.add(f, YAML.dump(@default_hash.merge(:fname => f)))
  end

  def add_namespace(ns)
    add_file(namespace_file(ns))
    @classes.each { |klass| add_class(ns, klass) }
  end

  def namespace_file(ns)
    if @domain_dir
      "#{@domain_dir}/#{ns}/#{MiqAeYamlImportExportMixin::NAMESPACE_YAML_FILENAME}"
    else
      "#{ns}/#{MiqAeYamlImportExportMixin::NAMESPACE_YAML_FILENAME}"
    end
  end

  def class_dir(ns, klass)
    if @domain_dir
      "#{@domain_dir}/#{ns}/#{klass}#{MiqAeYamlImportExportMixin::CLASS_DIR_SUFFIX}"
    else
      "#{ns}/#{klass}#{MiqAeYamlImportExportMixin::CLASS_DIR_SUFFIX}"
    end
  end

  def class_file(ns, klass)
    klass_dir = class_dir(ns, klass)
    "#{klass_dir}/#{MiqAeYamlImportExportMixin::CLASS_YAML_FILENAME}"
  end

  def add_class(ns, klass)
    klass_dir = class_dir(ns, klass)
    add_file("#{klass_dir}/#{MiqAeYamlImportExportMixin::CLASS_YAML_FILENAME}")
    @instances.each { |instance| add_instance(klass_dir, instance) }
    @methods.each { |method| add_method(klass_dir, method) }
  end

  def add_instance(klass_dir, instance)
    add_file("#{klass_dir}/#{instance}.yaml")
  end

  def add_method(klass_dir, method)
    method_dir = "#{klass_dir}/#{MiqAeYamlImportExportMixin::METHOD_FOLDER_NAME}"
    add_file("#{method_dir}/#{method}.yaml")
    add_file("#{method_dir}/#{method}.rb")
  end

  shared_examples_for "gitfs import" do
    it "#load_repo missing directory" do
      expect do
        MiqAeYamlImportGitfs.new(@domain, 'git_dir' => '/blah/blah/nada')
      end.to raise_error(MiqAeException::DirectoryNotFound)
    end

    it "#load_file" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect(@gitfs.load_file(@domain_file)).to have_attributes(@default_hash.merge(:fname => @domain_file))
    end

    it "#load_file invalid" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect { @gitfs.load_file("no_such_thing") }.to raise_error(GitWorktreeException::GitEntryMissing)
    end

    it "#domain_entry" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect(@gitfs.domain_entry(@domain_dir ? @domain : '.')).to eq(@domain_file)
    end

    it "#domain_entry invalid" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect { @gitfs.domain_entry("no such thing") }.to raise_error(MiqAeException::NamespaceNotFound)
    end

    it "#namespace_files" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      ns_files = @namespaces.collect { |ns| namespace_file(ns) }
      expect(@gitfs.namespace_files(@domain_dir ? @domain : '.')).to match_array(ns_files)
    end

    it "#namespace_files invalid" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect(@gitfs.namespace_files("no such thing")).to be_empty
    end

    it "#class_files invalid" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      expect(@gitfs.class_files("no_such_thing")).to be_empty
    end

    it "#class_files" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      ns_files = @namespaces.collect { |ns| namespace_file(ns) }
      ns_dir   = File.dirname(ns_files[0])
      ns = ns_dir.split('/').last
      class_files = @classes.collect { |klass| class_file(ns, klass) }
      expect(@gitfs.class_files(ns_dir)).to match_array(class_files)
    end

    it "#get_instance_files" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      ns_files = @namespaces.collect { |ns| namespace_file(ns) }
      ns_dir   = File.dirname(ns_files[0])
      ns = ns_dir.split('/').last
      class_files = @classes.collect { |klass| class_file(ns, klass) }
      class_dir = File.dirname(class_files[0])
      instance_files = @instances.collect { |instance| "#{class_dir}/#{instance}.yaml" }
      expect(@gitfs.get_instance_files(class_dir)).to match_array(instance_files)
    end

    it "#get_method_files" do
      @gitfs = MiqAeYamlImportGitfs.new(@domain, 'git_dir' => @repo_path)
      ns_files = @namespaces.collect { |ns| namespace_file(ns) }
      ns_dir   = File.dirname(ns_files[0])
      ns = ns_dir.split('/').last
      class_files = @classes.collect { |klass| class_file(ns, klass) }
      class_dir = File.dirname(class_files[0])
      method_dir = "#{class_dir}/#{MiqAeYamlImportExportMixin::METHOD_FOLDER_NAME}"
      method_files = @methods.collect { |method| "#{method_dir}/#{method}.yaml" }
      expect(@gitfs.get_method_files(class_dir)).to match_array(method_files)
    end
  end

  context "without top level directory" do
    before do
      build_git_repository("ManageIQ", nil)
    end

    it_should_behave_like "gitfs import"
  end

  context "with top level directory" do
    before do
      build_git_repository("ManageIQ", "ManageIQ")
    end

    it_should_behave_like "gitfs import"
  end
end
