require_relative 'test_containers_persister'

class TestCollector
  class << self
    def generate_batches_of_partial_container_group_data(ems_name:, resource_version:, batch_size: 4, index_start: 0, persister: nil)
      ems       = ExtManagementSystem.find_by(:name => ems_name)
      persister ||= new_persister(ems)

      (index_start * batch_size..((index_start + 1) * batch_size - 1)).each do |index|
        parse_partial_container_group(index, persister, resource_version + index * 100)
      end

      persister
    end

    def generate_batches_of_different_partial_container_group_data(ems_name:, resource_version:, batch_size: 4, index_start: 0, persister: nil)
      ems       = ExtManagementSystem.find_by(:name => ems_name)
      persister ||= new_persister(ems)

      (index_start * batch_size..((index_start + 1) * batch_size - 1)).each do |index|
        parse_another_partial_container_group(index, persister, resource_version + index * 100)
      end

      persister
    end

    def generate_batches_of_full_container_group_data(ems_name:, resource_version:, batch_size: 4, index_start: 0, persister: nil)
      ems       = ExtManagementSystem.find_by(:name => ems_name)
      persister ||= new_persister(ems)

      (index_start * batch_size..((index_start + 1) * batch_size - 1)).each do |index|
        parse_container_group(index, persister, resource_version + index * 100)
      end

      persister
    end

    def parse_another_partial_container_group(index, persister, partial_newest)
      persister.container_groups.build_partial(
        :ems_ref          => "container_group_#{index}",
        :resource_version => partial_newest,
        :reason           => partial_newest,
        :message          => partial_newest,
        :dns_policy       => "#{index}",
      )
    end

    def parse_partial_container_group(index, persister, partial_newest)
      persister.container_groups.build_partial(
        :ems_ref          => "container_group_#{index}",
        :phase            => "#{partial_newest} status",
        :resource_version => partial_newest,
        :reason           => partial_newest,
        :dns_policy       => "#{index}",
      )
    end

    def parse_container_group(index, persister, version)
      persister.container_groups.build(
        :ems_ref          => "container_group_#{index}",
        :dns_policy       => "#{index}",
        :name             => "container_group_#{version}",
        :phase            => "#{version} status",
        :resource_version => version,
        :reason           => version,
        :message          => version,
      )
    end

    def refresh(persister)
      persister.class.from_json(persister.to_json).persist!
    end

    def new_persister(ems)
      TestContainersPersister.new(ems, ems)
    end
  end
end
