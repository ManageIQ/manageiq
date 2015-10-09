#!/usr/bin/env ruby

class JohnnyFive
  SKIP_FILE=".skip-ci"

  attr_accessor :pr
  attr_accessor :branch
  attr_accessor :commit
  attr_accessor :commit_range
  attr_accessor :first_commit # calculated from comit_range
  attr_accessor :last_commit # calculated from git
  attr_accessor :component
  attr_accessor :verbose

  alias verbose? verbose
  alias pr? pr

  attr_accessor :changed_files # calculated from git

  def read_args(argv = [])
    @verbose = argv.detect { |arg| arg == "-v" } || true # always verbose for now
    @touch   = argv.detect { |arg| arg == "-t" } || true # always create file
  end

  def read_env(env = ENV)
    @pr     = env['TRAVIS_PULL_REQUEST'] != "false"
    @branch = env['TRAVIS_BRANCH']
    @commit = env['TRAVIS_COMMIT']
    @commit_range = env['TRAVIS_COMMIT_RANGE'] || ""
    @component = env["TEST_SUITE"] || env["GEM"]
  end

  def file_ref
    if pr?
      if first_commit == "" || first_commit.nil?
        # Travis-CI is not yet passing a commit range for pull requests
        # so we must use the automerge's changed file list. This has the
        # negative effect that new pushes to the PR will immediately
        # start affecting any new jobs, regardless of the build they are on
        debug("No first commit, using Github's automerge commit")
        "--first-parent -1 -m FETCH_HEAD"
      elsif first_commit == last_commit
        # There is only one commit in the pull request so far,
        # or Travis-CI is not yet passing the commit range properly
        # for pull requests. We examine just the one commit using -1
        #
        # On the oddball chance that it's a merge commit, we pray
        # it's a merge from upstream and also pass --first-parent
        debug("Only one commit in range, examining #{last_commit}")
        "-m --first-parent -1 #{last_commit}"
      else
        # In case they merged in upstream, we only care about the first
        # parent. For crazier merges, we hope
        "--first-parent #{first_commit}...#{last_commit}"
      end
    else
      debug('I am not testing a pull request')
        # Three main scenarios to consider
        #  - 1 One non-merge commit pushed to master
        #  - 2 One merge commit pushed to master (e.g. a PR was merged).
        #      This is an example of merging a topic branch
        #  - 3 Multiple commits pushed to master
        #
        #  1 and 2 are actually handled the same way, by showing the
        #  changes being brought into to master when that one commit
        #  was merged. Fairly simple, `git log -1 COMMIT`. To handle
        #  the potential merge of a topic branch you also include
        #  `--first-parent -m`.
        #
        #  3 needs to be handled by comparing all merge children for
        #  the entire commit range. The best solution here would *not*
        #  use --first-parent because there is no guarantee that it
        #  reflects changes brought into master. Unfortunately we have
        #  no good method inside Travis-CI to easily differentiate
        #  scenario 1/2 from scenario 3, so I cannot handle them all
        #  separately. 1/2 are the most common cases, 3 with a range
        #  of non-merge commits is the next most common, and 3 with
        #  a range including merge commits is the least common, so I
        #  am choosing to make our Travis-CI setup potential not work
        #  properly on the least common case by always using
        #  --first-parent

        # Handle 3
        # Note: Also handles 2 because Travis-CI sets COMMIT_RANGE for
        # merged PR commits
      "--first-parent -m #{commit_range}"
    end

    # Handle 1
    # "--first-parent -m -1 #{commit}"
  end

  def first_commit
    @first_commit = (commit_range || "").split("...").first
  end

  def last_commit
    @last_commit ||= `git rev-list -n 1 FETCH_HEAD^2`.chomp
  end

  def changed_files
    @changed_files ||= `git log --name-only --pretty=\"format:\" #{file_ref}`.split("\n")
  end

  def inform
    if pr?
      puts "PR    BRANCH: #{branch}"
      puts "COMMIT_RANGE: #{commit_range}"
      puts "first_commit: #{first_commit}"
      puts "last_commit : #{last_commit}"
    else
      puts "merge into master (#{branch})"
      puts "COMMIT_RANGE: #{commit_range}"
    end
    puts "COMMIT      : #{commit}"
    puts "component   : #{component}"
    puts "file ref    : #{file_ref}"
    if verbose?
      puts "CHANGED FILES:"
      puts "---"
      puts changed_files.uniq.sort.join("\n")
      puts "---"
    end
  end

  def skip(justification = nil)
    justification = "SKIPPING: #{justification}\n"
    puts justification
    File.write(SKIP_FILE, justification)
  end

  def parse(argv, env)
    read_args(argv)
    read_env(env)
    self
  end

  def run
    inform
    #skip("Im being trigger happy") if pr?
  end

  def debug(msg)
    puts "DEBUG: #{msg}" # if verbose?
  end

  def self.run(argv, env)
    new.parse(argv, env).run
  end

  def self.file(pattern, target, except = nil)
  end

  def self.trigger(src_target, dependent_target, options = nil)
  end

  ## configuration
  def self.targets
    @@targets ||= []
  end

  def self.test?(test_target)
  end

  def self.config
    yield self
  end
end

JohnnyFive.config do |cfg|
  # suite, and how it depends upon
  # REPLICATION_SPECS = FileList['spec/replication/**/*_spec.rb']
  # MIGRATION_SPECS   = FileList['spec/migrations/**/*_spec.rb'].sort
  # AUTOMATION_SPECS  = FileList['spec/automation/**/*_spec.rb']
  # EvmTestHelper::VMDB_SPECS

  # src file (glob)                    target name that changed
  cfg.file "app/assets",               "vmdb-ui"
  cfg.file "app/controllers/api_controller", "vmdb-api"
  cfg.file "app/controllers",          "vmdb-ui", :except => %r{app/controllers/api_controller/}
  cfg.file "app/helpers",              "vmdb-ui"
  cfg.file "app/mailers",              "vmdb-ui"
  cfg.file "app/models",               "vmdb"
  cfg.file "app/presenters",           "vmdb-ui"
  cfg.file "app/services",             "vmdb-ui"
  cfg.file "app/views",                "vmdb-ui"
  cfg.file "{bin,build_tools,certs}/", :none
  cfg.file "config/",                  :all # routes - lots of stuff here
  cfg.file "config.ru",                %(vmdb-ui self_service), :exact => true # self service?
  cfg.file "data",                     :none
  cfg.file "db",                       "vmdb-db"
  cfg.file "extras",                   :none
  cfg.file "Gemfile",                  :all
  cfg.file "gems/cfme_client",         "cfme_client"
  cfg.file "gems/pending/Gemfile",     %w(vmdb pending), :exact => true
  cfg.file "gems/pending/",            "pending"
  cfg.file "gems/manageiq_foreman/",   "manageiq_foreman"
  cfg.file "lib/",                     "vmdb", :ext => "*.rb"
  cfg.file "product/",                 "vmdb-ui"
  cfg.file "public/",                  %w(vmdb-ui self_service)
  cfg.file "script/",                  :none
  cfg.file "spa_ui/self_service/",     "self_service"
  cfg.file "spec/automation",          "automation-specs", :ext => "_spec.rb"
  cfg.file "spec/replication/",        "replication-specs", :ext => "_spec.rb"
  cfg.file "spec/migrations/",         "migrations-specs", :ext => "_spec.rb"
  cfg.file "spec/",                    "vmdb-specs", :except  => /^spec\/(replication|migrations|automation)/, :ext => "_spec.rb"
  cfg.file "spec/",                    :all, :except  => /^_spec.rb/
  cfg.file "tools/",                   "vmdb-tools"
  cfg.file "vendor/",                  "vmdb-ui"
  cfg.file "{CHANGELOG.md,CONTRIBUTING.md,LICENSE.*,README.md,VERSION}$", :none, :exact => true

  #           target              other targets that are affected
  cfg.trigger "cfme_client",      %w(vmdb)
  cfg.trigger "manageiq_foreman", %w(vmdb)
  cfg.trigger "pending",          %w(vmdb)
  cfg.trigger "vmdb-db",          %w(vmdb replication migrations)
  cfg.trigger "vmdb-ui",          %w(self_service)
  cfg.trigger "vmdb",             %w(automation)

  # specs
  cfg.trigger "automation",       "automation-specs"
  cfg.trigger "vmdb",             "brakeman-specs" # always run?
  cfg.trigger "cfme_client",      "cfme_client-specs"
  cfg.trigger "pending",          "pending-specs"
  cfg.trigger "self_service",     "self_service-specs"
  cfg.trigger "manageiq_foreman", "manageiq_foreman-specs"
  cfg.trigger "vmdb-tools",       "vmdb-specs"
  cfg.trigger "vmdb-ui",          "vmdb-specs"
  cfg.trigger "vmdb",             %w(vmdb-specs)
  cfg.trigger "replication",      "replication-specs"
  cfg.trigger "migrations",       "migrations-specs"
  cfg.trigger "vmdb-ui",          "javascript-specs" # always run?
end

JohnnyFive.run(ARGV, ENV)
