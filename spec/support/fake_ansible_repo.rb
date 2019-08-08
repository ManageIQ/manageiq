# = Spec::Support::FakeAnsibleRepo
#
# Extracted from EmbeddedAnsible::AutomationManager::ConfigurationScriptSource
#
# Generates a dummy local git repository with a configurable file structure.
# The repo just needs to be given a repo_path and a file tree definition.
#
#     file_tree_definition = %w[
#       roles/foo/tasks/main.yml
#       requirements.yml
#       playbook.yml
#     ]
#     FakeAnsibleRepo.generate "/path/to/my_repo", file_tree_definition
#
#     other_repo = FakeAnsibleRepo.new "/path/to/my/other_repo", file_tree_definition
#     other_repo.generate
#     other_repo.git_branch_create "patch_1"
#     other_repo.git_branch_create "patch_2"
#
#
# == File Tree Definition
#
# The file tree definition (file_struct) is just passed in as a word array for
# each file/empty-dir entry for the repo#
#
# So for a single file repo with a `hello_world.yml` playbook, the definition
# as a HEREDOC string would be:
#
#     file_struct = %w[
#       hello_world.yaml
#     ]
#
# This will generate a repo with a single file called `hello_world.yml`.  For a
# more complex example:
#
#     file_struct = %w[
#       azure_servers/azure_playbook.yml
#       azure_servers/roles/azure_stuffs/requirements.yml
#       azure_servers/roles/azure_stuffs/tasks/main.yml
#       azure_servers/roles/azure_stuffs/defaults/main.yml
#       aws_servers/roles/s3_stuffs/tasks/main.yml
#       aws_servers/roles/s3_stuffs/defaults/main.yml
#       aws_servers/roles/ec2_config/tasks/main.yml
#       aws_servers/roles/ec2_config/defaults/main.yml
#       aws_servers/aws_playbook.yml
#       aws_servers/s3_playbook.yml
#       openshift/roles/
#       localhost/requirements.yml
#       localhost/localhost_playbook.yml
#     ]
#
# NOTE:  directories only need to be defined on their own if they are intended
# to be empty, otherwise a defining files in them is enough.
#
#
# == Reserved file names/paths
#
# Most files with `.yml` or `.yaml` will be generated for some dummy content
# for a playbook:
#
#     - name: filename.yml
#       hosts: all
#       tasks:
#         - name: filename.yml Message
#           debug:
#             msg: "Hello World! (from filename.yml)"
#
# This is mostly to allow for testing playbook detecting code.  To the end,
# there are also "reserved" filenames that you can use to generate alternative
# dummy content that is not in a playbook format.
#
#
# === requirements.yml
#
# Regardless of where you put this file, if found, it will generate a sample
# `ansible-galaxy` requirements file.
#
#     - src: yatesr.timezone
#     - src: https://github.com/bennojoy/nginx
#     - src: https://github.com/bennojoy/nginx
#       version: master
#         name: nginx_role
#
#
# === roles/**/meta/main.yml
#
# Will generate a "Role Dependencies" yaml definition:
#
#     ---
#     dependencies:
#       - role: common
#         vars:
#           some_parameter: 3
#       - role: apache
#         vars:
#           apache_port: 80
#
#
# === extra_vars.yml, roles/**/vars/*.yml, and roles/**/defaults/*.yml
#
# Generates sample variable files
#
#     ---
#     var_1: foo
#     var_2: bar
#     var_3: baz
#

require "rugged"

require "pathname"
require "fileutils"

module Spec
  module Support
    class FakeAnsibleRepo
      REQUIREMENTS = <<~REQUIREMENTS.freeze
        - src: yatesr.timezone
        - src: https://github.com/bennojoy/nginx
        - src: https://github.com/bennojoy/nginx
          version: master
            name: nginx_role
      REQUIREMENTS

      META_DATA = <<~ROLE_DEPS.freeze
        ---
        dependencies:
          - role: common
            vars:
              some_parameter: 3
          - role: apache
            vars:
              apache_port: 80
      ROLE_DEPS

      VAR_DATA = <<~VARS.freeze
        ---
        var_1: foo
        var_2: bar
        var_3: baz
      VARS

      attr_reader :file_struct, :repo_path, :repo, :index

      def self.generate(repo_path, file_struct)
        new(repo_path, file_struct).generate
      end

      def initialize(repo_path, file_struct)
        @repo_path   = Pathname.new(repo_path)
        @name        = @repo_path.basename
        @file_struct = file_struct
      end

      def generate
        build_repo(repo_path, file_struct)

        git_init
        git_add_all
        git_commit_initial
      end

      # Create a new branch (don't checkout)
      #
      #   $ git branch other_branch
      #
      def git_branch_create(new_branch_name)
        repo.create_branch(new_branch_name)
      end

      private

      # Generate repo structure based on file_structure array
      #
      # By providing a directory location and an array of paths to generate,
      # this will build a repository directory structure.  If a specific entry
      # ends with a '/', then an empty directory will be generated.
      #
      # Example file structure array:
      #
      #     file_struct = %w[
      #       roles/defaults/main.yml
      #       roles/meta/main.yml
      #       roles/tasks/main.yml
      #       host_vars/
      #       hello_world.yml
      #     ]
      #
      def build_repo(repo_path, file_structure)
        file_structure.each do |entry|
          path          = repo_path.join(entry)
          dir, filename = path.split unless entry.end_with?("/")
          FileUtils.mkdir_p(dir || entry)

          next unless filename

          build_file(dir, filename)
        end
      end

      VAR_FILE_FNMATCHES = [
        "**/extra_vars.{yml,yaml}",
        "**/roles/*/vars/*.{yml,yaml}",
        "**/roles/*/defaults/*.{yml,yaml}"
      ].freeze

      # Generates a single file
      #
      # If it is a reserved file name/path, then the contents are generated,
      # otherwise it will be a empty file.
      #
      def build_file(repo_rel_path, entry)
        full_path = repo_rel_path.join(entry)
        content   = if filepath_match?(full_path, "**/requirements.{yml,yaml}")
                      REQUIREMENTS
                    elsif filepath_match?(full_path, *VAR_FILE_FNMATCHES)
                      VAR_DATA
                    elsif filepath_match?(full_path, "**/roles/*/meta/main.{yml,yaml}")
                      META_DATA
                    elsif filepath_match?(full_path, "**/*.{yml,yaml}")
                      dummy_playbook_data_for(full_path.basename)
                    end

        File.write(full_path, content)
      end

      # Given a collection of glob based `File.fnmatch` strings, confirm
      # whether any of them match the given path.
      #
      def filepath_match?(path, *acceptable_matches)
        acceptable_matches.any? { |match| path.fnmatch?(match, File::FNM_EXTGLOB) }
      end

      # Init new repo at local_repo
      #
      #   $ cd /tmp/clone_dir/hello_world_local && git init .
      #
      def git_init
        @repo  = Rugged::Repository.init_at(repo_path.to_s)
        @index = repo.index
      end

      # Add new files to index
      #
      #   $ git add .
      #
      def git_add_all
        index.add_all
        index.write
      end

      # Create initial commit
      #
      #   $ git commit -m "Initial Commit"
      #
      def git_commit_initial
        Rugged::Commit.create(
          repo,
          :message    => "Initial Commit",
          :parents    => [],
          :tree       => index.write_tree(repo),
          :update_ref => "HEAD"
        )
      end

      # Generates dummy playbook file content
      #
      # If the filename ends with ".encrypted.yml", then it will be
      # "encrypted", in which the content is made to look like it was.
      #
      # Since copying the encryption scheme of ansible-vault is outside the
      # scope of this class, it simply does enough to emulate what a encrypted
      # file looks like, which is:
      #
      #   - Adding the header ("$ANSIBLE_VAULT;1.1;AES256")
      #   - "Encrypting" the data (just double converting it to hex)
      #   - Taking the encrypted data and converting it to 80 chars
      #
      def dummy_playbook_data_for(filename)
        data = <<~PLAYBOOK_DATA
          - name: #{filename}
            hosts: all
            tasks:
              - name: #{filename} Message
                debug:
                  msg: "Hello World! (from #{filename})"
        PLAYBOOK_DATA

        if filename.basename.fnmatch?("*.encrypted.{yml,yaml}", File::FNM_EXTGLOB)
          to_hex = data.unpack1("H*").unpack1("H*")
          data   = (0...to_hex.length).step(80).to_a
                                      .map! { |start| to_hex[start, 80] }
                                      .prepend("$ANSIBLE_VAULT;1.1;AES256")
                                      .append("")
                                      .join("\n")
        end

        data
      end
    end
  end
end
