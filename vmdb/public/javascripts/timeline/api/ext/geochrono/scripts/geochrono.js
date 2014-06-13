/*==================================================
 *  Geochrono
 *==================================================
 */

Timeline.Geochrono = new Object();

Timeline.Geochrono.eons = [
    {   name: "Proterozoic",
        start: 2500.000
    },
    {   name: "Phanerozoic",
        start: 542.000
    }
];

Timeline.Geochrono.eras = [
    {   name: "Paleoarchean",
        start: 3600.000
    },
    {   name: "Mesoarchean",
        start: 3200.000
    },
    {   name: "Neoarchean",
        start: 2800.000
    },
    {   name: "Paleoproterozoic",
        start: 2500.000
    },
    {   name: "Mesoproterozoic",
        start: 1600.000
    },
    {   name: "Neoproterozoic",
        start: 1000.000
    },
    {   name: "Paleozoic",
        start: 542.000
    },
    {   name: "Mesozoic",
        start: 251.000
    },
    {   name: "Cenozoic",
        start: 65.500
    }
];

Timeline.Geochrono.periods = [
    {   name: "Siderian",
        start: 2500.000
    },
    {   name: "Rhyacian",
        start: 2300.000
    },
    {   name: "Orosirian",
        start: 2050.000
    },
    {   name: "Statherian",
        start: 1800.000
    },
    {   name: "Calymmian",
        start: 1600.000
    },
    {   name: "Ectasian",
        start: 1400.000
    },
    {   name: "Stenian",
        start: 1200.000
    },
    {   name: "Tonian",
        start: 1000.000
    },
    {   name: "Cryogenian",
        start: 850.000
    },
    {   name: "Ediacaran",
        start: 600.000
    },
    {   name: "Cambrian",
        start: 542.000
    },
    {   name: "Ordovician",
        start: 488.300
    },
    {   name: "Silurian",
        start: 443.700
    },
    {   name: "Devonian",
        start: 416.000
    },
    {   name: "Carboniferous",
        start: 359.200
    },
    {   name: "Permian",
        start: 299.000
    },
    {   name: "Triassic",
        start: 251.000
    },
    {   name: "Jurassic",
        start: 199.600
    },
    {   name: "Cretaceous",
        start: 145.500
    },
    {   name: "Paleogene",
        start: 65.500
    },
    {   name: "Neogene",
        start: 23.030
    }
];

Timeline.Geochrono.epoches = [
    {   name: "Lower Cambrian",
        start: 542.000
    },
    {   name: "Middle Cambrian",
        start: 513.000
    },
    {   name: "Furongian",
        start: 501.000
    },
    {   name: "Lower Ordovician",
        start: 488.300
    },
    {   name: "Middle Ordovician",
        start: 471.800
    },
    {   name: "Upper Ordovician",
        start: 460.900
    },
    {   name: "Llandovery",
        start: 443.700
    },
    {   name: "Wenlock",
        start: 428.200
    },
    {   name: "Ludlow",
        start: 422.900
    },
    {   name: "Pridoli",
        start: 418.700
    },
    {   name: "Lower Devonian",
        start: 416.000
    },
    {   name: "Middle Devonian",
        start: 397.500
    },
    {   name: "Upper Devonian",
        start: 385.300
    },
    {   name: "Mississippian",
        start: 359.200
    },
    {   name: "Pennsylvanian",
        start: 318.100
    },
    {   name: "Cisuralian",
        start: 299.000
    },
    {   name: "Guadalupian",
        start: 270.600
    },
    {   name: "Lopingian",
        start: 260.400
    },
    {   name: "Lower Triassic",
        start: 251.000
    },
    {   name: "Middle Triassic",
        start: 245.000
    },
    {   name: "Upper Triassic",
        start: 228.000
    },
    {   name: "Lower Jurassic",
        start: 199.600
    },
    {   name: "Middle Jurassic",
        start: 175.600
    },
    {   name: "Upper Jurassic",
        start: 161.200
    },
    {   name: "Lower Cretaceous",
        start: 145.500
    },
    {   name: "Upper Cretaceous",
        start: 99.600
    },
    {   name: "Paleocene",
        start: 65.500
    },
    {   name: "Eocene",
        start: 55.800
    },
    {   name: "Oligocene",
        start: 33.900
    },
    {   name: "Miocene",
        start: 23.030
    },
    {   name: "Pliocene",
        start: 5.332
    },
    {   name: "Pleistocene",
        start: 1.806
    },
    {   name: "Holocene",
        start: 0.012
    }
];

Timeline.Geochrono.ages = [
    {   name: "-",
        start: 542.000
    },
    {   name: "-",
        start: 513.000
    },
    {   name: "Paibian",
        start: 501.000
    },
    {   name: "Tremadocian",
        start: 488.300
    },
    {   name: "-",
        start: 478.600
    },
    {   name: "-",
        start: 471.800
    },
    {   name: "Darriwilian",
        start: 468.100
    },
    {   name: "-",
        start: 460.900
    },
    {   name: "-",
        start: 455.800
    },
    {   name: "Hirnantian",
        start: 445.600
    },
    {   name: "Rhuddanian",
        start: 443.700
    },
    {   name: "Aeronian",
        start: 439.000
    },
    {   name: "Telychian",
        start: 436.100
    },
    {   name: "Sheinwoodian",
        start: 428.200
    },
    {   name: "Homerian",
        start: 426.200
    },
    {   name: "Gorstian",
        start: 422.900
    },
    {   name: "Ludfordian",
        start: 421.300
    },
    {   name: "-",
        start: 418.700
    },
    {   name: "Lochkovian",
        start: 416.000
    },
    {   name: "Pragian",
        start: 411.200
    },
    {   name: "Emsian",
        start: 407.000
    },
    {   name: "Eifelian",
        start: 397.500
    },
    {   name: "Givetian",
        start: 391.800
    },
    {   name: "Frasnian",
        start: 385.300
    },
    {   name: "Famennian",
        start: 374.500
    },
    {   name: "Tournaisian",
        start: 359.200
    },
    {   name: "Visean",
        start: 345.300
    },
    {   name: "Serpukhovian",
        start: 326.400
    },
    {   name: "Bashkirian",
        start: 318.100
    },
    {   name: "Moscovian",
        start: 311.700
    },
    {   name: "Kazimovian",
        start: 306.500
    },
    {   name: "Gzhelian",
        start: 303.900
    },
    {   name: "Asselian",
        start: 299.000
    },
    {   name: "Sakmarian",
        start: 294.600
    },
    {   name: "Artinskian",
        start: 284.400
    },
    {   name: "Kungurian",
        start: 275.600
    },
    {   name: "Roadian",
        start: 270.600
    },
    {   name: "Wordian",
        start: 268.000
    },
    {   name: "Capitanian",
        start: 265.800
    },
    {   name: "Wuchiapingian",
        start: 260.400
    },
    {   name: "Changhsingian",
        start: 253.800
    },
    {   name: "Induan",
        start: 251.000
    },
    {   name: "Olenekian",
        start: 249.700
    },
    {   name: "Anisian",
        start: 245.000
    },
    {   name: "Ladinian",
        start: 237.000
    },
    {   name: "Carnian",
        start: 228.000
    },
    {   name: "Norian",
        start: 216.500
    },
    {   name: "Rhaetian",
        start: 203.600
    },
    {   name: "Hettangian",
        start: 199.600
    },
    {   name: "Sinemurian",
        start: 196.500
    },
    {   name: "Pliensbachian",
        start: 189.600
    },
    {   name: "Toarcian",
        start: 183.000
    },
    {   name: "Aalenian",
        start: 175.600
    },
    {   name: "Bajocian",
        start: 171.600
    },
    {   name: "Bathonian",
        start: 167.700
    },
    {   name: "Callovian",
        start: 164.700
    },
    {   name: "Oxfordian",
        start: 161.200
    },
    {   name: "Kimmeridgian",
        start: 155.000
    },
    {   name: "Tithonian",
        start: 150.800
    },
    {   name: "Berriasian",
        start: 145.500
    },
    {   name: "Valanginian",
        start: 140.200
    },
    {   name: "Hauterivian",
        start: 136.400
    },
    {   name: "Barremian",
        start: 130.000
    },
    {   name: "Aptian",
        start: 125.000
    },
    {   name: "Albian",
        start: 112.000
    },
    {   name: "Cenomanian",
        start: 99.600
    },
    {   name: "Turonian",
        start: 93.500
    },
    {   name: "Coniacian",
        start: 89.300
    },
    {   name: "Santonian",
        start: 85.800
    },
    {   name: "Campanian",
        start: 83.500
    },
    {   name: "Maastrichtian",
        start: 70.600
    },
    {   name: "Danian",
        start: 65.500
    },
    {   name: "Selandian",
        start: 61.700
    },
    {   name: "Thanetian",
        start: 58.700
    },
    {   name: "Ypresian",
        start: 55.800
    },
    {   name: "Lutetian",
        start: 48.600
    },
    {   name: "Bartonian",
        start: 40.400
    },
    {   name: "Priabonian",
        start: 37.200
    },
    {   name: "Rupelian",
        start: 33.900
    },
    {   name: "Chattian",
        start: 28.400
    },
    {   name: "Aquitanian",
        start: 23.030
    },
    {   name: "Burdigalian",
        start: 20.430
    },
    {   name: "Langhian",
        start: 15.970
    },
    {   name: "Serravallian",
        start: 13.650
    },
    {   name: "Tortonian",
        start: 11.608
    },
    {   name: "Messinian",
        start: 7.246
    },
    {   name: "Zanclean",
        start: 5.332
    },
    {   name: "Piacenzian",
        start: 3.600
    },
    {   name: "Gelasian",
        start: 2.588
    }
];


Timeline.Geochrono.createBandInfo = function(params) {
    var theme = ("theme" in params) ? params.theme : Timeline.getDefaultTheme();
    
    var eventSource = ("eventSource" in params) ? params.eventSource : null;
    
    var ether = new Timeline.LinearEther({ 
        centersOn:          ("date" in params) ? params.date : Timeline.GeochronoUnit.makeDefaultValue(),
        interval:           1,
        pixelsPerInterval:  params.intervalPixels
    });
    
    var etherPainter = new Timeline.GeochronoEtherPainter({
        intervalUnit:       params.intervalUnit, 
        multiple:           ("multiple" in params) ? params.multiple : 1,
        align:              params.align,
        theme:              theme 
    });
    
    var layout = new Timeline.StaticTrackBasedLayout({
        eventSource:    eventSource,
        ether:          ether,
        showText:       ("showEventText" in params) ? params.showEventText : true,
        theme:          theme
    });
    
    var eventPainterParams = {
        showText:   ("showEventText" in params) ? params.showEventText : true,
        layout:     layout,
        theme:      theme
    };
    if ("trackHeight" in params) {
        eventPainterParams.trackHeight = params.trackHeight;
    }
    if ("trackGap" in params) {
        eventPainterParams.trackGap = params.trackGap;
    }
    var eventPainter = new Timeline.DurationEventPainter(eventPainterParams);
    
    return {   
        width:          params.width,
        eventSource:    eventSource,
        timeZone:       ("timeZone" in params) ? params.timeZone : 0,
        ether:          ether,
        etherPainter:   etherPainter,
        eventPainter:   eventPainter
    };
};