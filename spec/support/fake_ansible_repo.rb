#
# Generates a dummy local git repository with a configurable file structure.
# The repo just needs to be given a repo_path and a file tree definition.
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

require_relative "fake_git_repo"

module Spec
  module Support
    class FakeAnsibleRepo < FakeGitRepo
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

      private

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
      def file_content(full_path)
        if filepath_match?(full_path, "**/requirements.{yml,yaml}")
          REQUIREMENTS
        elsif filepath_match?(full_path, *VAR_FILE_FNMATCHES)
          VAR_DATA
        elsif filepath_match?(full_path, "**/roles/*/meta/main.{yml,yaml}")
          META_DATA
        elsif filepath_match?(full_path, "**/*.{yml,yaml}")
          dummy_playbook_data_for(full_path.basename)
        end
      end

      # Given a collection of glob based `File.fnmatch` strings, confirm
      # whether any of them match the given path.
      #
      def filepath_match?(path, *acceptable_matches)
        acceptable_matches.any? { |match| path.fnmatch?(match, File::FNM_EXTGLOB) }
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
