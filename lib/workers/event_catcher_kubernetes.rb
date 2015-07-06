require 'workers/event_catcher'
require 'workers/mixins/event_catcher_kubernetes_mixin'

class EventCatcherKubernetes < EventCatcher
  include EventCatcherKubernetesMixin
end
