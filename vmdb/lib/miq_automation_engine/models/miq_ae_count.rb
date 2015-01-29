module MiqAeCount
  extend ActiveSupport::Concern

  module ClassMethods
    def fetch_count(klass)
      counts = Hash.new { |h, k| h[k] = 0 }
      domain_list.each { |domain| stats(domain, counts, klass) }
      counts[klass.to_s]
    end

    def stats(domain, counts, klass)
      repo =  git_repository(domain)
      list = repo.list_files
      send("process_#{klass.to_s.underscore}_count", repo, list, counts)
    end

    def process_miq_ae_field_count(repo, list, counts)
      method_and_input_count(repo, list, counts, 'MiqAeField')
      class_and_field_count(repo, list, counts, 'MiqAeField')
    end

    def process_miq_ae_value_count(repo, list, counts)
      instance_and_value_count(repo, list, counts, 'MiqAeValue')
    end

    def process_miq_ae_class_count(repo, list, counts)
      class_and_field_count(repo, list, counts, 'MiqAeClass')
    end

    def process_miq_ae_instance_count(repo, list, counts)
      instance_and_value_count(repo, list, counts, 'MiqAeInstance')
    end

    def process_miq_ae_method_count(repo, list, counts)
      method_and_input_count(repo, list, counts, 'MiqAeMethod')
    end

    def process_miq_ae_namespace_count(_repo, list, counts)
      counts['MiqAeNamespace'] += namespace_list(list).count
    end

    def process_miq_ae_domain_count(_repo, list, counts)
      counts['MiqAeDomain'] += list.select { |f| File.basename(f) == MiqAeFsStore::DOMAIN_YAML_FILE }.count
    end

    def domain_list(name = '*')
      Dir.glob(File.join(MiqAeDatastore::DATASTORE_DIRECTORY, '*')).collect do |entry|
        domain = File.basename(entry)
        next unless File.fnmatch(name, domain, File::FNM_CASEFOLD)
        domain
      end.compact
    end

    def namespace_list(list, name = '*')
      list.select do |f|
        File.basename(f) == MiqAeFsStore::NAMESPACE_YAML_FILE &&
          File.fnmatch(name, File.basename(File.dirname(f)), File::FNM_CASEFOLD)
      end
    end

    def method_list(list, name = '*')
      list.select do |f|
        File.basename(File.dirname(f)) == MiqAeFsStore::METHODS_DIRECTORY &&
          File.extname(f) == '.yaml' &&
          File.fnmatch(name, File.basename(f).split('.')[0], File::FNM_CASEFOLD)
      end
    end

    def class_list(list, name = '*')
      list.select do |f|
        File.basename(f) == MiqAeFsStore::CLASS_YAML_FILE &&
          File.fnmatch(name, File.basename(File.dirname(f)).split('.')[0], File::FNM_CASEFOLD)
      end
    end

    def instance_list(list, name = '*')
      list.select do |f|
        File.basename(File.dirname(f)).ends_with?(MiqAeFsStore::CLASS_DIR_SUFFIX) &&
          File.extname(f) == '.yaml' && File.basename(f) != MiqAeFsStore::CLASS_YAML_FILE &&
          File.fnmatch(name, File.basename(f).split('.')[0], File::FNM_CASEFOLD)
      end
    end

    def method_and_input_count(repo, list, counts, class_type)
      methods = method_list(list)
      counts['MiqAeMethod'] += methods.count
      return if class_type == 'MiqAeMethod'
      methods.each do |m|
        yaml_hash = YAML.load(repo.read_file(m))
        counts['MiqAeField'] += yaml_hash['object']['inputs'].count
      end
    end

    def instance_and_value_count(repo, list, counts, class_type)
      instances = instance_list(list)
      counts['MiqAeInstance'] += instances.count
      return if class_type == 'MiqAeInstance'
      instances.each do |i|
        yaml_hash = YAML.load(repo.read_file(i))
        counts['MiqAeValue'] += yaml_hash['object']['fields'].count
      end
    end

    def class_and_field_count(repo, list, counts, class_type)
      classes = class_list(list)
      counts['MiqAeClass'] += classes.count
      return if class_type == 'MiqAeClass'
      classes.each do |c|
        yaml_hash = YAML.load(repo.read_file(c))
        counts['MiqAeField'] += yaml_hash['object']['schema'].count
      end
    end
  end
end
