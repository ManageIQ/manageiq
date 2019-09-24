FactoryBot.define do
  factory :hardware do
    trait(:cpu1x1) do
      cpu_sockets          { 1 }
      cpu_cores_per_socket { 1 }
      cpu_total_cores      { 1 }
    end

    trait(:cpu2x2) do
      cpu_sockets          { 2 }
      cpu_cores_per_socket { 2 }
      cpu_total_cores      { 4 }
    end

    trait(:cpu1x2) do
      cpu_sockets          { 1 }
      cpu_cores_per_socket { 2 }
      cpu_total_cores      { 2 }
    end

    trait(:cpu4x2) do
      cpu_sockets          { 4 }
      cpu_cores_per_socket { 2 }
      cpu_total_cores      { 8 }
    end

    trait(:ram1GB) { memory_mb { 1024 } }
  end
end
