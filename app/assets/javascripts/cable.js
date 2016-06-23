//= require action_cable
//= require_self
//= require_tree ./channels

ManageIQ.notifications = ActionCable.createConsumer('/ws/notifications');
