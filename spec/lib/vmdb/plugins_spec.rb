RSpec.describe Vmdb::Plugins do
  it ".all" do
    all = described_class.all

    expect(all).to include(
      ManageIQ::Providers::Vmware::Engine,
      ManageIQ::UI::Classic::Engine
    )
    expect(all).to_not include(
      ActionCable::Engine
    )
  end

  it ".ansible_content" do
    ansible_content = described_class.ansible_content

    content = ansible_content.detect { |ac| ac.path.to_s.include?("manageiq-content") }
    expect(content.path).to eq ManageIQ::Content::Engine.root.join("content/ansible")

    content = ansible_content.detect { |ac| ac.path.to_s.include?("manageiq-ui-classic") }
    expect(content).to_not be
  end

  it ".automate_domains" do
    automate_domains = described_class.automate_domains

    domain = automate_domains.detect { |ac| ac.name == "ManageIQ" }
    expect(domain.path).to eq ManageIQ::Content::Engine.root.join("content/automate/ManageIQ")

    domain = automate_domains.detect { |ac| ac.path.to_s.include?("manageiq-ui-classic") }
    expect(domain).to_not be
  end

  describe ".asset_paths" do
    it "with normal engines" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::UI::Classic::Engine" }
      expect(asset_path.path).to eq ManageIQ::UI::Classic::Engine.root
      expect(asset_path.namespace).to eq "manageiq-ui-classic"
    end

    it "with engines with inflections" do
      asset_paths = described_class.asset_paths

      asset_path = asset_paths.detect { |ap| ap.name == "ManageIQ::V2V::Engine" }
      expect(asset_path.path).to eq ManageIQ::V2V::Engine.root
      expect(asset_path.namespace).to eq "manageiq-v2v"
    end
  end

  it ".provider_plugins" do
    provider_plugins = described_class.provider_plugins

    expect(provider_plugins).to include(
      ManageIQ::Providers::Vmware::Engine,
      ManageIQ::Providers::Amazon::Engine
    )
    expect(provider_plugins).to_not include(
      ManageIQ::Api::Engine,
      ManageIQ::UI::Classic::Engine
    )
  end

  it ".details" do
    details = described_class.details

    expect(details).to be_kind_of(Hash)
    expect(details.keys).to match_array described_class.all

    detail = details.values.first
    expect(detail).to be_kind_of(Hash)
    expect(detail.keys).to match_array([:name, :version, :path])
  end

  it ".versions" do
    versions = described_class.versions

    expect(versions).to be_kind_of(Hash)
    expect(versions.keys).to match_array described_class.all
  end

  describe ".version (private)" do
    subject { described_class.send(:instance).send(:version, engine) }

    let(:engine) { Class.new(Rails::Engine) }

    def clear_versions_caches
      described_class.send(:instance).instance_variable_set(:@bundler_specs_by_path, nil)
    end

    before { clear_versions_caches }
    after  { clear_versions_caches }

    def with_temp_dir(options)
      Dir.mktmpdir("plugins_spec") do |dir|
        allow(engine).to receive(:root).and_return(Pathname.new(dir))

        if options[:symlinked]
          with_temp_symlink(dir) { |ln| yield ln }
        else
          yield dir
        end
      end
    end

    def with_temp_symlink(dir)
      Dir::Tmpname.create("plugins_spec") do |ln|
        FileUtils.ln_s(dir, ln)
        begin
          yield ln
        ensure
          FileUtils.remove_entry(ln)
        end
      end
    end

    def with_temp_git_dir(options)
      with_temp_dir(options) do |dir|
        sha = nil

        Dir.chdir(dir) do
          `
          git init &&
          touch foo  && git add -A && git commit -m "Added foo" --no-gpg-sign &&
          touch foo2 && git add -A && git commit -m "Added foo2" --no-gpg-sign
          `

          if options[:branch] == "master"
            sha = `git rev-parse HEAD`.strip
          else
            sha = `git rev-parse HEAD~`.strip
            `git checkout #{"-b #{options[:branch]}" if options[:branch]} #{sha} 2>/dev/null`
            `git tag #{options[:tag]}` if options[:tag]
          end
        end

        yield dir, sha
      end
    end

    def with_spec(type, options = {})
      raise "Unexpected type '#{type}'" unless %i(git path_with_git path).include?(type)

      source =
        if type == :git
          instance_double(Bundler::Source::Git, :branch => options[:branch], :options => {"tag" => options[:tag]})
        else
          instance_double(Bundler::Source::Path)
        end

      allow(Bundler::Source::Git).to receive(:===).with(source).and_return(type == :git)
      allow(Bundler::Source::Path).to receive(:===).with(source).and_return(type != :git)

      method = (type == :path ? :with_temp_dir : :with_temp_git_dir)

      send(method, options) do |dir, sha|
        expect(source).to receive(:revision).and_return(sha) if type == :git

        spec = instance_double(Gem::Specification, :full_gem_path => dir, :source => source)
        expect(Bundler.load).to receive(:specs).and_return([spec])

        yield(sha && sha[0, 8])
      end
    end

    it "git based, on master" do
      with_spec(:git, :branch => "master") do |sha|
        expect(subject).to eq("master@#{sha}")
      end
    end

    it "git based, on a branch" do
      with_spec(:git, :branch => "my_branch") do |sha|
        expect(subject).to eq("my_branch@#{sha}")
      end
    end

    it "git based, on a tag" do
      with_spec(:git, :tag => "my_tag") do |sha|
        expect(subject).to eq("my_tag@#{sha}")
      end
    end

    it "git based, on a sha" do
      with_spec(:git) do |sha|
        expect(subject).to eq(sha)
      end
    end

    it "path based, with git, on master" do
      with_spec(:path_with_git, :branch => "master") do |sha|
        expect(subject).to eq("master@#{sha}")
      end
    end

    it "path based, with git, on a branch" do
      with_spec(:path_with_git, :branch => "my_branch") do |sha|
        expect(subject).to eq("my_branch@#{sha}")
      end
    end

    it "path based, with git, on a tag" do
      with_spec(:path_with_git, :tag => "my_tag") do |sha|
        expect(subject).to eq("my_tag@#{sha}")
      end
    end

    it "path based, with git, on a sha" do
      with_spec(:path_with_git) do |sha|
        expect(subject).to eq(sha)
      end
    end

    it "path based, without git" do
      with_spec(:path) do
        expect(subject).to be_nil
      end
    end

    it "symlinked path based, with git, on master" do
      with_spec(:path_with_git, :symlinked => true, :branch => "master") do |sha|
        expect(subject).to eq("master@#{sha}")
      end
    end

    it "symlinked path based, with git, on a branch" do
      with_spec(:path_with_git, :symlinked => true, :branch => "my_branch") do |sha|
        expect(subject).to eq("my_branch@#{sha}")
      end
    end

    it "symlinked path based, with git, on a tag" do
      with_spec(:path_with_git, :symlinked => true, :tag => "my_tag") do |sha|
        expect(subject).to eq("my_tag@#{sha}")
      end
    end

    it "symlinked path based, with git, on a sha" do
      with_spec(:path_with_git, :symlinked => true) do |sha|
        expect(subject).to eq(sha)
      end
    end

    it "symlinked path based, without git" do
      with_spec(:path, :symlinked => true) do
        expect(subject).to be_nil
      end
    end
  end

  it "all plugins will implement .plugin_name" do
    bad_plugins = described_class.select { |plugin| plugin.try(:plugin_name).blank? }
    expect(bad_plugins).to be_empty
  end
end
