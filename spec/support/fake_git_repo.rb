# = Spec::Support::FakeGitRepo
#
# Generates a dummy local git repository with a configurable file structure.
# The repo just needs to be given a repo_path and a file tree definition.
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

require "rugged"

require "pathname"
require "fileutils"

module Spec
  module Support
    class FakeGitRepo
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

      # Generates a single file
      #
      # If it is a reserved file name/path, then the contents are generated,
      # otherwise it will be a empty file.
      #
      def build_file(repo_rel_path, entry)
        full_path = repo_rel_path.join(entry)
        content   = file_content(full_path)

        File.write(full_path, content)
      end

      def file_content(*)
        raise NotImplementedError
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
        author = {:email => "admin@localhost", :name => "admin", :time => Time.now.utc}

        Rugged::Commit.create(
          repo,
          :message    => "Initial Commit",
          :parents    => [],
          :tree       => index.write_tree(repo),
          :update_ref => "HEAD",
          :author     => author,
          :committer  => author
        )
      end
    end
  end
end
