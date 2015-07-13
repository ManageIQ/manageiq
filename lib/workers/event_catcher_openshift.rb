require 'workers/event_catcher'
require 'workers/mixins/event_catcher_kubernetes_mixin'

class EventCatcherOpenshift < EventCatcher
  include EventCatcherKubernetesMixin
end
