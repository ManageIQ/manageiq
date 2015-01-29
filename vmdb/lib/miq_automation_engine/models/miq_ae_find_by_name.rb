require 'parallel'
module MiqAeFindByName
  extend ActiveSupport::Concern

  module ClassMethods
    def fetch_all_by_name(name, klass, commit_sha_hash = {})
      Parallel.map(domain_list, :in_threads => 0) do |domain|
        send("fetch_all_#{klass.to_s.underscore}_by_name", domain, name, commit_sha_hash[domain])
      end.compact.flatten
    end

    def fetch_by_name(name, klass, commit_sha_hash = {})
      Parallel.map(domain_list, :in_threads => 0) do |domain|
        send("fetch_#{klass.to_s.underscore}_by_name", domain, name, commit_sha_hash[domain])
      end.compact.flatten.first
    end

    def fetch_all_miq_ae_domain_by_name(domain, name, commit_sha = nil)
      return [] unless File.fnmatch(name, domain, File::FNM_CASEFOLD)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      list.select { |f| File.basename(f) == MiqAeFsStore::DOMAIN_YAML_FILE }.collect do |f|
        load_ae_entry(repo, repo.find_entry(f), MiqAeDomain)
      end
    end

    def fetch_miq_ae_domain_by_name(domain, name, commit_sha = nil)
      return nil unless File.fnmatch(name, domain, File::FNM_CASEFOLD)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      domain_file = list.detect { |f| f == "/#{MiqAeFsStore::DOMAIN_YAML_FILE}" }
      load_ae_entry(repo, repo.find_entry(domain_file), MiqAeDomain) if domain_file
    end

    def fetch_all_miq_ae_namespace_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      namespace_list(list, name).collect { |f| load_ae_entry(repo, repo.find_entry(f), MiqAeNamespace) }
    end

    def fetch_miq_ae_namespace_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      namespace_file = namespace_list(list, name).first
      load_ae_entry(repo, repo.find_entry(namespace_file), MiqAeNamespace) if namespace_file
    end

    def fetch_all_miq_ae_class_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      class_list(list, name).collect { |f| load_ae_entry(repo, repo.find_entry(f), MiqAeClass) }
    end

    def fetch_miq_ae_class_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      class_file = class_list(list, name).first
      load_ae_entry(repo, repo.find_entry(class_file), MiqAeClass) if class_file
    end

    def fetch_all_miq_ae_instance_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      instance_list(list, name).collect { |f| load_ae_entry(repo, repo.find_entry(f), MiqAeInstance) }
    end

    def fetch_miq_ae_instance_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      instance_file = instance_list(list, name).first
      load_ae_entry(repo, repo.find_entry(instance_file), MiqAeInstance) if instance_file
    end

    def fetch_all_miq_ae_method_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      puts list
      method_list(list, name).collect { |f| load_ae_entry(repo, repo.find_entry(f), MiqAeMethod) }
    end

    def fetch_miq_ae_method_by_name(domain, name, commit_sha)
      repo, list = fetch_file_list_from_repo(domain, commit_sha)
      method_file = method_list(list, name).first
      load_ae_entry(repo, repo.find_entry(method_file), MiqAeMethod) if method_file
    end

    def fetch_file_list_from_repo(domain, commit_sha)
      repo = git_repository(domain)
      return repo, repo.list_files(commit_sha)
    end
  end
end
