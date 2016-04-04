
// Util: PatternFly Tertiary Vertical Navigation
// Must have navbar-toggle in navbar-pf-vertical for expand/collapse
(function ($) {
  'use strict';

  $.fn.setupVerticalTertiaryNavigation = function (handleItemSelections) {

    var navElement = $('.nav-pf-vertical'),
      bodyContentElement = $('.container-pf-nav-pf-vertical'),
      toggleNavBarButton = $('.navbar-toggle'),
      explicitCollapse = false,
      subDesktop = false,
      breakpoints = {
        'tablet': 768,
        'desktop': 1200
      },

      inMobileState = function () {
        return bodyContentElement.hasClass('hidden-nav');
      },

      forceResize = function () {
        setTimeout(function () {
          if (window.dispatchEvent) {
            window.dispatchEvent(new Event('resize'));
          }
          // Special case for IE
          if ($(document).fireEvent) {
            $(document).fireEvent('onresize');
          }
        }, 100);
      },

      setPrimaryActiveItem = function (item) {
        // Make the clicked on item active
        $(document).find('.nav-pf-vertical > .list-group > .list-group-item.active').each(function (index, element) {
          $(element).removeClass('active');
        });
        item.addClass('active');
      },

      setSecondaryActiveItem = function (item, $primaryParent) {
        $(document).find('.nav-pf-secondary-nav > .list-group > .list-group-item.active').each(function (index, element) {
          $(element).removeClass('active');
        });
        item.addClass('active');

        setPrimaryActiveItem($primaryParent);
      },

      setTertiaryActiveItem = function (item, $secondaryParent, $primaryParent) {
        $(document).find('.nav-pf-tertiary-nav > .list-group > .list-group-item.active').each(function (index, element) {
          $(element).removeClass('active');
        });
        item.addClass('active');

        setSecondaryActiveItem($secondaryParent, $primaryParent);
      },

      updateMobileMenu = function (selected, secondaryItem) {
        $(document).find('.list-group-item.mobile-nav-item-pf').each(function (index, item) {
          $(item).removeClass('mobile-nav-item-pf');
        });
        $(document).find('.list-group-item.mobile-secondary-item-pf').each(function (index, item) {
          $(item).removeClass('mobile-secondary-item-pf');
        });
        if (selected) {
          selected.addClass('mobile-nav-item-pf');
          if (secondaryItem) {
            secondaryItem.addClass('mobile-secondary-item-pf');
            navElement.removeClass('show-mobile-secondary');
            navElement.addClass('show-mobile-tertiary');
          } else {
            navElement.addClass('show-mobile-secondary');
            navElement.removeClass('show-mobile-tertiary');
          }
        } else {
          navElement.removeClass('show-mobile-secondary');
          navElement.removeClass('show-mobile-tertiary');
        }
      },

      updateSecondaryCollapsedState = function (setCollapsed, collapsedItem) {
        if (setCollapsed) {
          collapsedItem.addClass('collapsed');
          navElement.addClass('collapsed-secondary-nav-pf');
          bodyContentElement.addClass('collapsed-secondary-nav-pf');
        } else {
          if (collapsedItem) {
            collapsedItem.removeClass('collapsed');
          } else {
            // Remove any collapsed secondary menus
            navElement.find('[data-toggle="collapse-secondary-nav"]').each(function (index, element) {
              var $e = $(element);
              $e.removeClass('collapsed');
            });
          }
          navElement.removeClass('collapsed-secondary-nav-pf');
          bodyContentElement.removeClass('collapsed-secondary-nav-pf');
        }
      },

      updateTertiaryCollapsedState = function (setCollapsed, collapsedItem) {
        if (setCollapsed) {
          collapsedItem.addClass('collapsed');
          navElement.addClass('collapsed-tertiary-nav-pf');
          bodyContentElement.addClass('collapsed-tertiary-nav-pf');
          updateSecondaryCollapsedState(false);
        } else {
          if (collapsedItem) {
            collapsedItem.removeClass('collapsed');
          } else {
            // Remove any collapsed tertiary menus
            navElement.find('[data-toggle="collapse-tertiary-nav"]').each(function (index, element) {
              var $e = $(element);
              $e.removeClass('collapsed');
            });
          }
          navElement.removeClass('collapsed-tertiary-nav-pf');
          bodyContentElement.removeClass('collapsed-tertiary-nav-pf');
        }
      },

      checkNavState = function () {
        var width = $(window).width();

        // Check to see if we need to enter/exit the mobile state
        if (width < breakpoints.tablet) {
          if (!navElement.hasClass('hidden')) {
            //Set the nav to being hidden
            navElement.addClass('hidden');
            navElement.removeClass('collapsed');

            //Set the body class to the correct state
            bodyContentElement.removeClass('collapsed-nav');
            bodyContentElement.addClass('hidden-nav');

            // Reset the collapsed states
            updateSecondaryCollapsedState(false);
            updateTertiaryCollapsedState(false);

            explicitCollapse = false;
          }
        } else if (navElement.hasClass('hidden')) {
          // Always remove the hidden & peek class
          navElement.removeClass('hidden show-mobile-nav');

          // Set the body class back to the default
          bodyContentElement.removeClass('hidden-nav');
        }

        if (explicitCollapse) {
          navElement.addClass('collapsed');
          bodyContentElement.addClass('collapsed-nav');
        } else {
          navElement.removeClass('collapsed');
          bodyContentElement.removeClass('collapsed-nav');
        }
      },

      collapseMenu = function () {
        //Make sure this is expanded
        navElement.addClass('collapsed');
        //Set the body class to the correct state
        bodyContentElement.addClass('collapsed-nav');
        explicitCollapse = true;
      },

      enableTransitions = function () {
        // enable transitions only when toggleNavBarButton is clicked or window is resized
        $('html').addClass('transitions');
      },

      expandMenu = function () {
        //Make sure this is expanded
        navElement.removeClass('collapsed');
        //Set the body class to the correct state
        bodyContentElement.removeClass('collapsed-nav');

        explicitCollapse = false;

        // Dispatch a resize event when showing the expanding then menu to
        // allow content to adjust to the menu sizing
        if (!subDesktop) {
          forceResize();
        }
      },

      bindMenuBehavior = function () {
        toggleNavBarButton.on('click', function (e) {
          enableTransitions();

          if (inMobileState()) {
            // Toggle the mobile nav
            if (navElement.hasClass('show-mobile-nav')) {
              navElement.removeClass('show-mobile-nav');
            } else {
              // Always start at the primary menu
              updateMobileMenu();
              navElement.addClass('show-mobile-nav');
            }
          } else if (navElement.hasClass('collapsed')) {
            expandMenu();
          } else {
            collapseMenu();
          }
        });
      },

      forceHideSecondaryMenu = function () {
        navElement.addClass('force-hide-secondary-nav-pf');
        setTimeout(function () {
          navElement.removeClass('force-hide-secondary-nav-pf');
        }, 500);
      },

      bindMenuItemsBehavior = function (handleSelection) {
        $(document).find('.nav-pf-vertical > .list-group > .list-group-item').each(function (index, primaryItem) {
          var $primaryItem = $(primaryItem);

          // Set main nav active item on click or show secondary nav if it has a secondary nav bar and we are in the mobile state
          $primaryItem.on('click.pf.secondarynav.data-api', function (event) {
            var $this = $(this);

            if (!$this.hasClass('secondary-nav-item-pf')) {
              if (inMobileState()) {
                updateMobileMenu();
                navElement.removeClass('show-mobile-nav');
              }
              if (handleSelection) {
                setPrimaryActiveItem($this);
                // Don't process the click on the item
                event.stopImmediatePropagation();
              }
            }
            else if (inMobileState()) {
              updateMobileMenu($this);
            }
          });

          $primaryItem.find('.nav-pf-secondary-nav > .list-group > .list-group-item').each(function (index, secondaryItem) {
            var $secondaryItem = $(secondaryItem);
            // Set secondary nav active item on click or show tertiary nav if it has a tertiary nav bar and we are in the mobile state
            $secondaryItem.on('click.pf.secondarynav.data-api', function (event) {
              var $this = $(this);
              if (!$this.hasClass('tertiary-nav-item-pf')) {
                if (inMobileState()) {
                  updateMobileMenu();
                  navElement.removeClass('show-mobile-nav');
                }
                if (handleSelection) {
                  setSecondaryActiveItem($secondaryItem, $primaryItem);
                  // Don't process the click on the item
                  event.stopImmediatePropagation();
                }
              }
              else if (inMobileState()) {
                updateMobileMenu($this, $primaryItem);
                event.stopImmediatePropagation();
              }
            });

            $secondaryItem.find('.nav-pf-tertiary-nav > .list-group > .list-group-item').each(function (index, tertiaryItem) {
              var $tertiaryItem = $(tertiaryItem);
              // Set tertiary nav active item on click
              $tertiaryItem.on('click.pf.secondarynav.data-api', function (event) {
                if (inMobileState()) {
                  updateMobileMenu();
                  navElement.removeClass('show-mobile-nav');
                }
                if (handleSelection) {
                  setTertiaryActiveItem($tertiaryItem, $secondaryItem, $primaryItem);
                  // Don't process the click on the item
                  event.stopImmediatePropagation();
                }
              });
            });
          });
        });

        $(document).find('.secondary-nav-item-pf').each(function (index, secondaryItem) {
          var $secondaryItem = $(secondaryItem);

          // Collapse the secondary nav bar when the toggle is clicked
          $secondaryItem.on('click.pf.secondarynav.data-api', '[data-toggle="collapse-secondary-nav"]', function (e) {
            var $this = $(this);
            if (inMobileState()) {
              updateMobileMenu();
              e.stopImmediatePropagation();
            } else {
              if ($this.hasClass('collapsed')) {
                updateSecondaryCollapsedState(false, $this);
                forceHideSecondaryMenu();
              } else {
                updateSecondaryCollapsedState(true, $this);
              }
            }
            navElement.removeClass('hover-secondary-nav-pf');
            if (handleSelection) {
              // Don't process the click on the parent item
              e.stopImmediatePropagation();
            }
          });

          $secondaryItem.find('.tertiary-nav-item-pf').each(function (index, primaryItem) {
            var $primaryItem = $(primaryItem);
            // Collapse the tertiary nav bar when the toggle is clicked
            $primaryItem.on('click.pf.tertiarynav.data-api', '[data-toggle="collapse-tertiary-nav"]', function (e) {
              var $this = $(this);
              if (inMobileState()) {
                updateMobileMenu($secondaryItem);
                e.stopImmediatePropagation();
              } else {
                if ($this.hasClass('collapsed')) {
                  updateTertiaryCollapsedState(false, $this);
                  forceHideSecondaryMenu();
                } else {
                  updateTertiaryCollapsedState(true, $this);
                }
              }
              navElement.removeClass('hover-secondary-nav-pf');
              navElement.removeClass('hover-tertiary-nav-pf');
              if (handleSelection) {
                // Don't process the click on the parent item
                e.stopImmediatePropagation();
              }
            });
          });
        });

        // Show secondary nav bar on hover of secondary nav items
        $(document).on('mouseover.pf.tertiarynav.data-api', '.secondary-nav-item-pf', function (e) {
          if (!inMobileState()) {
            navElement.addClass('hover-secondary-nav-pf');
          }
        });
        $(document).on('mouseout.pf.tertiarynav.data-api', '.secondary-nav-item-pf', function (e) {
          navElement.removeClass('hover-secondary-nav-pf');
        });

        // Show tertiary nav bar on hover of secondary nav items
        $(document).on('mouseover.pf.tertiarynav.data-api', '.tertiary-nav-item-pf', function (e) {
          if (!inMobileState()) {
            navElement.addClass('hover-tertiary-nav-pf');
          }
        });
        $(document).on('mouseout.pf.tertiarynav.data-api', '.tertiary-nav-item-pf', function (e) {
          navElement.removeClass('hover-tertiary-nav-pf');
        });
      },

      setTooltips = function () {
        $('.nav-pf-vertical [data-toggle="tooltip"]').tooltip({'container': 'body', 'delay': { 'show': '500', 'hide': '200' }});

        $(".nav-pf-vertical").on("show.bs.tooltip", function (e) {
          if (!$(this).hasClass("collapsed")) {
            return false;
          }
        });
      },

      init = function (handleItemSelections) {
        //Set correct state on load
        checkNavState();

        // Bind Top level hamburger menu with menu behavior;
        bindMenuBehavior();

        // Bind menu items
        bindMenuItemsBehavior(handleItemSelections);

        //Set tooltips
        setTooltips();
      };

    //Listen for the window resize event and collapse/hide as needed
    $(window).on('resize', function () {
      checkNavState();
      enableTransitions();
    });

    init(handleItemSelections);
  };
}(jQuery));
