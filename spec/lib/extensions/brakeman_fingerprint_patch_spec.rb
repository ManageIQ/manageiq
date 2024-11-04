RSpec.describe BrakemanFingerprintPatch do
  subject do
    Class.new do
      include BrakemanFingerprintPatch
      attr_accessor :file
      def initialize = @warning_code = 0
      def confidence = "High"
      def location = {}
    end.new
  end

  shared_examples_for "handles brakeman pathing" do
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new(core_path))
      allow(Rails::Engine).to receive(:subclasses).and_return([
        instance_double("Rails::Engine", :root => Pathname.new(engine_path)),
        instance_double("Rails::Engine", :root => Pathname.new(other_engine_path))
      ])
    end

    after do
      # Clear the rails_engine_paths cache
      described_class.remove_instance_variable(:@rails_engine_paths)
    end

    it "with an issue in core" do
      subject.file = core_issue

      expect(subject.file_string).to eq("lib/ansible/runner.rb")
      expect(subject.fingerprint).to eq("f06e25d3b6fa417a80313b2ebd451fbbeac3670f03897e26e86983a5c29635c1")
    end

    it "with an issue in the engine" do
      subject.file = engine_issue

      expect(subject.file_string).to eq("(engine:manageiq-ui-classic) app/controllers/application_controller.rb")
      expect(subject.fingerprint).to eq("1ea1c06c8976493622ad8c668f56df3a44aac997fabd57ab58fcf59a37712e56")
    end

    it "with an issue in some other engine" do
      subject.file = other_engine_issue

      expect(subject.file_string).to eq("(engine:manageiq-api) app/controllers/api/base_controller.rb")
      expect(subject.fingerprint).to eq("7e77fb5a61930045ff1581b4b25779e6fb6c951d31effe2ffb34725bfdecc454")
    end
  end

  let(:core_path) { "/Users/user/dev/manageiq" }
  let(:core_issue) do
    instance_double("Brakeman::FilePath",
      :relative => "lib/ansible/runner.rb",
      :absolute => "/Users/user/dev/manageiq/lib/ansible/runner.rb"
    )
  end

  context "running from the core repo" do
    context "with a git-based engine" do
      context "in the system gem location" do
        let(:engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end

      context "in a vendored gem location inside of the core repo" do # This is the core CI case
        let(:engine_path) { "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end
    end

    context "with a gem-based engine" do
      context "in the system gem location" do
        let(:engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0/app/controllers/application_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end

      context "in a vendored gem location inside of the core repo" do # This is a core CI case in a future where we might use a versioned gem
        let(:engine_path) { "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/dev/manageiq/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-0.1.0/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end
    end

    context "with a path-based engine" do
      context "which is a sibling of the core repo" do
        let(:engine_path) { "/Users/user/dev/manageiq-ui-classic" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../manageiq-ui-classic/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq-ui-classic/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/dev/manageiq-api" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../manageiq-api/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/dev/manageiq-api/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end

      context "which is a sibling of the core repo but some other engine is a git-based gem" do
        let(:engine_path) { "/Users/user/dev/manageiq-ui-classic" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../manageiq-ui-classic/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq-ui-classic/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end

      context "which is inside of the core repo" do
        let(:engine_path) { "/Users/user/dev/manageiq/plugins/manageiq-ui-classic" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "plugins/manageiq-ui-classic/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq/plugins/manageiq-ui-classic/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/dev/manageiq/plugins/manageiq-api" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "plugins/manageiq-api/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/dev/manageiq/plugins/manageiq-api/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end
    end
  end

  context "running from an engine repo" do
    context "with a symlinked spec/manageiq dir" do
      context "which is a sibling of the core repo but some other engine is a git-based gem" do
        let(:engine_path) { "/Users/user/dev/manageiq-ui-classic" } # When symlinked, then engine path appears the same as path-based gem, so this copies the test from aove
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../manageiq-ui-classic/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq-ui-classic/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end

      context "which is inside of the core repo but some other engine is a git-based gem" do
        let(:engine_path) { "/Users/user/dev/manageiq/plugins/manageiq-ui-classic" }
        let(:engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "plugins/manageiq-ui-classic/app/controllers/application_controller.rb",
            :absolute => "/Users/user/dev/manageiq/plugins/manageiq-ui-classic/app/controllers/application_controller.rb"
          )
        end

        let(:other_engine_path) { "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
        let(:other_engine_issue) do
          instance_double("Brakeman::FilePath",
            :relative => "../../.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
            :absolute => "/Users/user/.gem/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
          )
        end

        include_examples "handles brakeman pathing"
      end
    end

    context "with a cloned spec/manageiq dir" do # This is also the CI case for a plugin
      let(:core_path) { "/Users/user/dev/manageiq-ui-classic/spec/manageiq" }
      let(:core_issue) do
        instance_double("Brakeman::FilePath",
          :relative => "lib/ansible/runner.rb",
          :absolute => "/Users/user/dev/manageiq-ui-classic/spec/manageiq/lib/ansible/runner.rb"
        )
      end

      let(:engine_path) { "/Users/user/dev/manageiq-ui-classic" }
      let(:engine_issue) do
        instance_double("Brakeman::FilePath",
          :relative => "../../app/controllers/application_controller.rb",
          :absolute => "/Users/user/dev/manageiq-ui-classic/app/controllers/application_controller.rb"
        )
      end

      let(:other_engine_path) { "/Users/user/dev/manageiq-ui-classic/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f" }
      let(:other_engine_issue) do
        instance_double("Brakeman::FilePath",
          :relative => "../../vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb",
          :absolute => "/Users/user/dev/manageiq-ui-classic/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb"
        )
      end

      include_examples "handles brakeman pathing"
    end
  end
end
