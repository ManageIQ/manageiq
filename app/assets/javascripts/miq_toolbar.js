ManageIQ.toolbars = {};

ManageIQ.toolbars.findByDataClick = function (toolbar, attr_click) {
  return $(toolbar).find("[data-click='" + attr_click + "']");
};

ManageIQ.toolbars.enableItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).removeClass('disabled');
};

ManageIQ.toolbars.disableItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).addClass('disabled');
};

ManageIQ.toolbars.setItemTooltip = function (toolbar, attr_click, tooltip) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).attr('title', tooltip);
};

ManageIQ.toolbars.showItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).show();
};

ManageIQ.toolbars.hideItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).hide();
};

ManageIQ.toolbars.markItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).addClass('active');
};

ManageIQ.toolbars.unmarkItem = function (toolbar, attr_click) {
  ManageIQ.toolbars.findByDataClick(toolbar, attr_click).removeClass('active');
};
