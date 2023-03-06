// LIDAR
var context = new AudioContext();
var audioPlayer = null;
var clockTone = createClockTone(context);
var timerHandle;
var sniperscope = false;
var clockVolume = 0.02;
var selfTestVolume = 0.02;
var recordLimit = -1
var version = -1
var clockToneMute;
var databaseRecords = [];
var startTimer;

// TABLET
var map;
var dataTable;
var speedLimits = {};
var playerName;
var imgurApiKey;
var speedFilter = 0;
var mapMarkerPageOption = true
var mapMarkerPlayerOption = false
var legendWrapper;

var infowindow = new google.maps.InfoWindow()
const mapOptions = {
	center: new google.maps.LatLng(0, 0),
	zoom: 2,
	minZoom: 2,
	streetViewControl: false,
	mapTypeControl: false,
 };

fetch('../speedlimits.json')
  .then(response => response.json())
  .then(data => {
	speedLimits = data;
  })
  .catch(error => console.error('Unabled to fetch speedlimits.json:', error));
 
// Exit tablet hotkey 
$(document).keyup(function(event) {
	//			Esc
	if (event.keyCode == 27) 
	{
		$.post('http://ProLaser4/CloseTablet', "", function( datab ) {
			if ( datab != "ok" ) {
				console.log( datab );
			}            
		} );
	}
} );
 
$(document).ready(function () {
    $('#hud').hide();
    $('#lasergun').hide();
    $('#history-container').hide();
    $('#tablet').hide();
    $('#loading-dialog-container').hide();
	$('#closeTablet').click(function() { 
		mapMarkerPageOption = true;
		$('#btn-own').prop('checked', false);
		$('#btn-all-players').prop('checked', true);
		$('#btn-this-page').prop('checked', true);
		$('#btn-all-pages').prop('checked', false);		
				
		
		mapMarkerPlayerOption = false;
		dataTable.destroy();
		$('#clock-table-container').html(
			'<table id="clock-table" class="table table-striped table-bordered" cellspacing="0" width="100%">' +
			  '<thead>' +
				'<tr>' +
				  '<th class="rid">Record<br>ID</th>' +
				  '<th class="timestamp">Timestamp</th>' +
				  '<th class="speed">Speed<br>(mph)</th>' +
				  '<th class="distance">Distance<br>(feet)</th>' +
				  '<th class="player">Player</th>' +
				  '<th class="street">Street</th>' +
				  '<th class="mapping">Map</th>' +
				  '<th class="print">Print</th>' +
				'</tr>' +
			  '</thead>' +
			  '<tbody id="tBody">' +		   
			  '</tbody>' +
			'</table>'
		)
		$.post('http://ProLaser4/CloseTablet', "", function( datab ) {
			if ( datab != "ok" ) {
				console.log( datab );
			}            
		} );
	});
	$('#view-record-container').hide();
	$('#print-result-dialog-container').hide();
	
	$('#printPrintView').click( function() { 
		if (imgurApiKey != ''){
			$('#tablet').fadeOut();
			$('.printViewHeader').css('opacity', '0');
			$('#view-record').addClass('no-border');
			captureScreenshot();
			setTimeout(function(){
				$('#tablet').fadeIn();
				$('.printViewHeader').css('opacity', '1');
				$('#view-record').removeClass('no-border');
				$('.legend-wrapper').show();
			}, 1000)
		} else {
			$('#copyButton').hide();
			$('#dialogMsg').text("Upload Failed");
			$('#urlDisplay').text("No Imgur API set.");
			$('#print-result-dialog-container').fadeIn();
		}
	});
	
	$('#closePrintView').click( function() { 
		map.setOptions({
		  zoomControl: true,
		});
		$('#view-record-container').fadeOut();
		updateMarkers();
	});
	
	$('#copyButton').click( function() { 
		var textarea = document.createElement('textarea');
		textarea.value = $('#urlDisplay').text();
		document.body.appendChild(textarea);
		textarea.select();
		document.execCommand('copy');
		document.body.removeChild(textarea);
		$('#copyButton').text("Link Copied");
	});
	
	$('#closePrintDialog').click( function() { 
		$('#print-result-dialog-container').fadeOut();
	});
	
	// init map
	map = new google.maps.Map(
		document.getElementById('map'),
		mapOptions
	);

	map.mapTypes.set('gta_roadmap', roadmap);
	// sets default 'startup' map
	map.setMapTypeId('gta_roadmap');

	// Define an array of markers with custom icons and labels
	var markers = [ { icon: '', label: '<div class="legend-spacer" style="margin-top: -16px;">Own</div>' },
					{ icon: 'textures/map/green-dot-light.png', label: '< Speedlimit' },  
					{ icon: 'textures/map/yellow-dot-light.png', label: '> Speedlimit' },  
					{ icon: 'textures/map/red-dot-light.png', label: '> Speedlimit by 10 mph+' },
					{ icon: '', label: '<div class="legend-spacer" style="margin-top: -8px;">Peers</div>' },
					{ icon: 'textures/map/green-dot.png', label: '< Speedlimit' },
					{ icon: 'textures/map/yellow-dot.png', label: '> Speedlimit' },  
					{ icon: 'textures/map/red-dot.png', label: '> Speedlimit by 10 mph+' } ];

	// Create a new legend control
	var legend = document.createElement('div');
	legend.classList.add('legend-container');

	// Loop through the markers array and add each marker to the legend control
	markers.forEach(function(marker) {
	  var icon = marker.icon;
	  var label = marker.label;

	  var legendItem = document.createElement('div');
	  legendItem.classList.add('legend-item');

	  var iconImg = document.createElement('img');
	  iconImg.setAttribute('src', icon);
	  legendItem.appendChild(iconImg);

	  var labelSpan = document.createElement('span');
	  labelSpan.innerHTML = label;
	  legendItem.appendChild(labelSpan);

	  legend.appendChild(legendItem);
	});

	legendWrapper = document.createElement('div');
	legendWrapper.classList.add('legend-wrapper');
	legendWrapper.appendChild(legend);
	
    window.addEventListener('message', function (event) {
        if (event.data.action == 'SetLidarDisplayState') {
            if (event.data.state) {
                $('#lasergun').fadeIn();
            } else {
                $('#lasergun').fadeOut();
            }
        } else if (event.data.action == 'SendClockData') {
            $('#speed').text(event.data.speed);
            $('#range').text(event.data.range + 'ft');
            $('#rangehud').text(event.data.range + 'ft');
            $('#timer').text('');
            $('#lock').hide();
            $('#arrowup').hide();
            $('#arrowdown').hide();
            clearInterval(timerHandle);
            if (event.data.towards == true) {
                $('#speedhud').text('- ' + event.data.speed);
                $('#arrowup').hide();
                $('#arrowdown').show();
                timer();
                clearInterval(clockToneMute);
				playClockTone();
            } else if (event.data.towards == false) {
                $('#speedhud').text('+ ' + event.data.speed);
                $('#arrowdown').hide();
                $('#arrowup').show();
                timer();
                clearInterval(clockToneMute);
				playClockTone();
            } else {
                $('#speedhud').text('/ ' + event.data.speed);
                clearInterval(clockToneMute);
                clockTone.vol.gain.exponentialRampToValueAtTime(0.00001,context.currentTime + 0.1
                );
            }
        } else if (event.data.action == 'SetDisplayMode') {
            if (event.data.mode == 'ADS') {
                $('#hud').show();
                $('#lasergun').hide();
            } else {
                $('#hud').hide();
                $('#lasergun').show();
            }
        } else if (event.data.action == 'SetSelfTestState') {
            if (event.data.state) {
                $('#lidar-home').show();
                $('#self-test-container').hide();
                if (event.data.sound) {
                    playSound('LidarCalibration');
                }
            } else {
                clearInterval(timerHandle);
                $('#lidar-home').hide();
                $('#self-test-container').show();
				$('#self-test-timer').show();
                timer();
            }
        } else if (event.data.action == 'SendSelfTestProgress') {
            $('#self-test-progress').text(event.data.progress);
			if (event.data.stopTimer){
				$('#self-test-timer').hide();
                clearInterval(timerHandle);
			}
        } else if (event.data.action == 'scopestyle') {
            if (sniperscope) {
                $('#hud').css('background-image', 'url(textures/hud_sight.png)'
                );
            } else {
                $('#hud').css('background-image', 'url(textures/hud_sniper.png)'
                );
            }
            sniperscope = !sniperscope;
        } else if (event.data.action == 'SetConfigVars') {
            selfTestVolume = event.data.selfTestSFX;
            clockVolume = event.data.clockSFX;
			imgurApiKey = event.data.imgurApiKey;	
			recordLimit = event.data.recordLimit;
			version = event.data.version;
			$('#tablet-version').text('v'+version);
        } else if (event.data.action == 'SetHistoryState') {
            if (event.data.state) {
                $('#lidar-home').hide();
                $('#history-container').show();
            } else {
                $('#lidar-home').show();
                $('#history-container').hide();
            }
        } else if (event.data.action == 'SendHistoryData') {
            $('#counter').text(event.data.counter);
            $('#timestamp').text('Date Time: ' + event.data.time);
            $('#clock').text('Speed Range: ' + event.data.clock);
        } else if (event.data.action == 'PlayButtonPressBeep') {
            playSound(event.data.file);
        } else if (event.data.action == 'SendBatteryAmount') {
            $('#battery').attr('src', 'textures/battery' + event.data.bars + '.png'
            );
		} else if (event.data.action == 'GetCurrentDisplayData') {
			var returnData = { }
			returnData.onHistory = $('#history-container').is(':visible') ? true : false;
			if (returnData.onHistory) {
				returnData.counter 	= $('#counter').text();
				returnData.time 	= $('#timestamp').text().replace('Date Time: ', '');
				returnData.clock 	= $('#clock').text().replace('Speed Range: ', '');
			} else {
				returnData.speed = $('#speed').text();
				returnData.range = $('#range').text().replace('ft', '');
				if ($('#arrowup').is(':visible')){
					returnData.arrow = 1;
				} else if ($('#arrowdown').is(':visible')) {
					returnData.arrow = -1;
				} else {
					returnData.arrow = 0;
				}
				returnData.startTime = startTimer;
				returnData.battery = $('#battery').attr('src');
			}
			
			$.post( 'http://ProLaser4/ReturnCurrentDisplayData', JSON.stringify( returnData ), function( datab ) {
				if ( datab != "ok" ) {
					console.log( datab );
				}            
			} );
		} else if (event.data.action == 'SendPeersDisplayData') {
			$('#speed').text(event.data.speed);
            $('#range').text(event.data.range + 'ft');
			if ( event.data.arrow == 1){
				$('#arrowup').show();
				$('#arrowdown').hide();
			} else if ( event.data.arrow == -1 ) {
				$('#arrowup').hide();
				$('#arrowdown').show();
			} else {
				$('#arrowup').hide();
				$('#arrowdown').hide();
			}
			$('#battery').attr('src', event.data.battery );
			if (event.data.speed != '---') {
				clearInterval(timerHandle);
				timer(event.data.startTime);				
			}
        } else if (event.data.action == 'SendDatabaseRecords') {
			playerName = event.data.name;
			databaseRecords = JSON.parse(event.data.table);
			updateTabletWindow(playerName, databaseRecords);
        } else if (event.data.action == 'SetTabletState') {
            if (!event.data.state) {
                $('#tablet').fadeOut();
            }
        }
    });
});



// ======= MAIN SCRIPT =======
// Credit to xotikorukx playSound Fn.
function playSound(file) {
    if (audioPlayer != null) {
        audioPlayer.pause();
    }
	
    audioPlayer = new Audio('./sounds/' + file + '.ogg');
    audioPlayer.volume = selfTestVolume;
    var didPlayPromise = audioPlayer.play();

    if (didPlayPromise === undefined) {
        audioPlayer = null; //The audio player crashed. Reset it so it doesn't crash the next sound.
    } else {
        didPlayPromise
            .then(_ => {})
            .catch(error => {
                //This does not execute until the audio is playing.
                audioPlayer = null; //The audio player crashed. Reset it so it doesn't crash the next sound.
            });
    }
}

function createClockTone(audioContext) {
    let osc = audioContext.createOscillator();
    let vol = audioContext.createGain();

    osc.type = 'sine';
    osc.frequency.value = 0.5;
    vol.gain.value = 0.02;
    osc.connect(vol);
    vol.connect(audioContext.destination);
    osc.start(0);
    return { osc: osc, vol: vol };
}

String.prototype.toHHMMSS = function () {
    var sec_num = parseInt(this, 10); // don't forget the second param
    var minutes = Math.floor(sec_num / 60000);
    var seconds = Math.floor((sec_num - minutes * 60000) / 1000);

    if (minutes < 10) {
        minutes = '0' + minutes;
    }
    if (seconds < 10) {
        seconds = '0' + seconds;
    }
    return minutes + ':' + seconds;
};

function timer( start = Date.now() ) {
	startTimer = start;
    timerHandle = setInterval(function () {
        delta = Date.now() - start; // milliseconds elapsed since start
        $('#lock').show();
        $('#timer').show();
        $('#timer').text(delta.toString().toHHMMSS());
        $('#self-test-timer').text(delta.toString().toHHMMSS());
    }, 500); // update about every second
}

function playClockTone() {
    clockTone.osc.frequency.exponentialRampToValueAtTime(
        2300,
        context.currentTime + 0.1
    );
    clockTone.vol.gain.exponentialRampToValueAtTime(
        clockVolume,
        context.currentTime + 0.01
    );
    clockToneMute = setInterval(function () {
        clockTone.vol.gain.exponentialRampToValueAtTime(
            0.00001,
            context.currentTime + 0.1
        );
    }, 300); // update about every second
}
// ===== END MAIN SCRIPT ======

// ========= TABLET =========
// Define our custom map type
var roadmap = new google.maps.ImageMapType({
	getTileUrl: function (coords, zoom) {
		if (
			coords &&
			coords.x < Math.pow(2, zoom) &&
			coords.x > - 1 &&
			coords.y < Math.pow(2, zoom) &&
			coords.y > -1
		) {
			return (
				'textures/map/roadmap/' +
				zoom +
				'_' +
				coords.x +
				'_' +
				coords.y +
				'.jpg'
			);
		} else {
			return 'textures/map/roadmap/empty.jpg';
		}
	},
	tileSize: new google.maps.Size(256, 256),
	maxZoom: 5,
	minZoom: 2,
	zoom: 2,
	name: 'Roadmap',
});

function gtamp2googlepx(x, y) {
	// IMPORTANT
	// for this to work #map must be width:1126.69px; height:600px;
	// you can change this AFTER all markers are placed...
	//--------------------------------------
	//conversion increment from x,y to px,py
	var mx = 0.0503;
	var my = -0.0503; //-0.05003
	//math mVAR * cVAR
	var x = mx * x;
	var y = my * y;
	//offset for correction
	var x = x - 486.97;
	var y = y + 408.9;

	//return latlong coordinates
	return [x, y];
}


// Marker Function
function addMarker(id, x, y, content_html, icon) {
	//to ingame 2 google coords here, use function.
	var coords = gtamp2googlepx(x, y);
	var location = overlay
		.getProjection()
		.fromContainerPixelToLatLng(
			new google.maps.Point(coords[0], coords[1])
		);
	var marker = new google.maps.Marker({
		position: location,
		map: null,
		icon: 'textures/map/' + icon + '.png',
		optimized: false, //to prevent it from repeating on the x axis.
	});

	databaseRecords[id].googleLoc = location;
	databaseRecords[id].marker = marker;

	//when you click anywhere on the map, close all open windows...
	google.maps.event.addListener(marker, 'click', function () {
		infowindow.setContent(content_html);
		infowindow.open(map, marker);
		map.setCenter(new google.maps.LatLng(location));
		map.setZoom(6);

		google.maps.event.addListener(map, 'click', function () {
			infowindow.close();
		});
	});
}

function openInfo(element) {
    var elementRecord = databaseRecords[element.id];
    map.setCenter(new google.maps.LatLng(elementRecord.googleLoc));
    map.setZoom(5);
    infowindow.setContent(elementRecord.infoContent);
    infowindow.open(map, elementRecord.marker);
}

var loadedAlready = false
// Main window update function
function updateTabletWindow(playerName, databaseRecords){
	$('#tablet').fadeIn();
	$('#loading-dialog-container').fadeIn();
	
	overlay = new google.maps.OverlayView(); 
	overlay.draw = function () {};
	overlay.setMap(map);

	if (!loadedAlready){
		google.maps.event.addListenerOnce(map, 'tilesloaded', function () {
			loadedAlready = true;
			setTimeout(function() {
				processRecords(playerName, databaseRecords);
			}, 100)
		});
	} else {
		$('#map').attr("style", "");
		map = new google.maps.Map(document.getElementById('map'), mapOptions);
		overlay = new google.maps.OverlayView(); 
		overlay.draw = function () {};
		overlay.setMap(map);
		
		map.mapTypes.set('gta_roadmap', roadmap);
		map.setMapTypeId('gta_roadmap');

		google.maps.event.addListenerOnce(map, 'tilesloaded', function () {
			setTimeout(function() {
				processRecords(playerName, databaseRecords);
			}, 100)
		});
	}
}

function processRecords(playerName, databaseRecords){
	// Iterate through all records dynamically creating table, markers
	var tBodyRows = []
	for (var i = 0; i < databaseRecords.length; i++) {
		var record = databaseRecords[i];
		// Speedlimit conditional formatting
		var primaryStreet = record.street.includes('/')
			? [record.street.split('/')[0].trim()]
			: [record.street.trim()];
			
		var markerColor = 'green-dot';
		var speedString;
		var speedLimit = speedLimits[primaryStreet];
		
		if (speedLimit === undefined ) {
			speedString = '<td class="speed">' + record.speed + '</td>';
			console.log('^3Unable to locate speed limit of', primaryStreet);
		} else {
			if (record.speed < speedLimit) {
				speedString = '<td class="speed">' + record.speed + '</td>'; 
				markerColor = 'green-dot';
			} else if (record.speed > speedLimit + 10) {
				speedString = '<td class="speed" style="color: red">' + record.speed + '</td>';
				markerColor = 'red-dot';
			} else if (record.speed > speedLimit) {
				speedString = '<td class="speed" style="color: orange">' + record.speed + '</td>';
				markerColor = 'yellow-dot';
			}
		}

		
		// Generate marker info window content
		record.infoContent = '<b>RID: ' + record.rid + '</b><br>' + record.speed + 'mph<br>' + record.player;
		
		// Is own record conditional marker formatting
		if ( record.player == playerName ) {
			markerColor = markerColor + '-light'
		}
		
		// Add markers to map
		addMarker(i, record.targetX, record.targetY, record.infoContent, markerColor);
		
		// Add records to table
		tBodyRows.push(
			'<tr><td class="rid">' +
				record.rid +
			'</td>' +
			'<td class="timestamp">' + record.timestamp + '</td>' +
				speedString +
			'<td class="range">' + record.range + '</td>' +
			'<td class="player">' + record.player + '</td>' +
			'<td class="street" textContent="' + speedLimit + '">' + record.street + '</td>' +
			'<td class="mapping"><button class="tableBtn" id=' + i +' onClick="openInfo(this)"><i class="fa-sharp fa-solid fa-map-location-dot"></i></button></td>' +
			'<td class="print"><button class="tableBtn" id=' + i +' onClick="openPrintView(this)"><i class="fa-sharp fa-solid fa-print"></i></button></td></tr>'
		);
	}
	$('#tBody').append(tBodyRows.join(''));
	
	// Now that all GMap elements have been correctly caluated, update css to custom position.
	
	// Regenerate dataTable after inserting new tBody elements
	//	inefficent should be using dataTable.add() but conditional formatting; lazy;
	$('#loading-message').html('<i class="fa fa-spinner fa-spin" aria-hidden="true"></i> Building Table..');
	dataTable = $('#clock-table').DataTable({
		destroy: true,
		bPaginate: true,
		bLengthChange: false,
		bFilter: true,
		bInfo: true,
		bAutoWidth: false,
		"order": [[ 1, 'desc' ]],
		"aoColumnDefs": [ { "bSortable": false, "aTargets": [ 6, 7 ] } ],
		"initComplete": function(settings, json) {
			// only display markers on this page
			$('#clock-table').DataTable().on('draw.dt', function() {
				updateMarkers();
				
				//limited retrieval datatable footer
				var rows = $('#clock-table').DataTable().rows().count();
				if (rows == recordLimit) {
					var info = $('#clock-table_info');
					var text = info.text();
					var newText = text + " (limited by config)";
					info.text(newText);
				}
			});

			// dynamic row calulation
			var containerHeight = $('#clock-table-container').height();
			var rowHeight = $('#clock-table tbody tr:first-child').height();
			var numRows = Math.floor(containerHeight / rowHeight);
			$('#clock-table').DataTable().page.len(numRows).draw(); 
		}
	});


	$('#loading-message').html('<i class="fa fa-spinner fa-spin" aria-hidden="true"></i> Configuring Filters..');
	// Table speed filter handling
	$('#clock-table_filter').append(
		'<div class="dropdown" style="float: left !important;">' +
			'<button class="btn btn-default dropdown-toggle" type="button" data-toggle="dropdown" style="height: 27px; line-height: 6px;"><i class="fa-solid fa-filter"></i> Speed Filter ' +
			'<span class="caret"></span></button>' +
			'<ul class="dropdown-menu">' +
			'<li><a href="#" value="0" class="text-center">None</a></li>' +
			'<li><a href="#" value="20" class="text-center">20mph</a></li>' +
			'<li><a href="#" value="30" class="text-center">30mph</a></li>' +
			'<li><a href="#" value="40" class="text-center">40mph</a></li>' +
			'<li><a href="#" value="50" class="text-center">50mph</a></li>' +
			'<li><a href="#" value="60" class="text-center">60mph</a></li>' +
			'<li><a href="#" value="70" class="text-center">70mph</a></li>' +
			'<li><a href="#" value="80" class="text-center">80mph</a></li>' +
			'<li><a href="#" value="90" class="text-center">90mph</a></li>' +
			'<li><a href="#" value="100" class="text-center">100mph</a></li>' +
			'</ul>' +
			'</div>' +
			'</div>'
	);


	// Table speed filter handling
	$('.dropdown-menu a').click(function () {
		speedFilter = Number($(this).attr('value'))
		$.fn.dataTable.ext.search.push(function (
			settings,
			data,
			dataIndex
		) {
			return Number(data[2]) > speedFilter
				? true
				: false;
		});
		dataTable.draw();
		$.fn.dataTable.ext.search.pop();

		// after filtering table, update visible markers to match table
		updateMarkers();
	});
	
	// Map marker filters
	// Get all the button elements in the button groups
	const buttons = document.querySelectorAll('.btn-group input[type="radio"]');

	// Loop through each button and add a click event listener
	buttons.forEach(button => {
	  button.addEventListener('click', () => {
		// Get the value of the clicked button
		const buttonValue = button.nextElementSibling.textContent.trim();

		if (buttonValue == "All"){
			mapMarkerPageOption = false
			updateMarkers()
		} else if (buttonValue == "This Page") {
			mapMarkerPageOption = true
			updateMarkers()
		} else if (buttonValue == "Own") {
			mapMarkerPlayerOption = true
			updateMarkers()
		} else if (buttonValue == "All Players") {
			mapMarkerPlayerOption = false
			updateMarkers()
		} else if (buttonValue == "Off"){
			$('.legend-wrapper').addClass('hidden');
		} else if (buttonValue == "On"){
			$('.legend-wrapper').removeClass('hidden');
		}
	  });
	});
	
	// Add the legend after reinitalization
	$('#loading-message').html('<i class="fa fa-spinner fa-spin" aria-hidden="true"></i> Repositioning Map..');
	document.getElementById('map').style.cssText = 'position: relative; width: 40%; height: calc(100% - 116px); overflow: hidden; float: right; border: inset; z-index: 1; opacity:1;';
	map.controls[google.maps.ControlPosition.TOP_LEFT].push(legendWrapper);
	$('#loading-dialog-container').fadeOut();
}

// updates markers based on mapMarkerPageOption mapMarkerPlayerOption
function updateMarkers() {
	var idsArray = [];
	if (mapMarkerPageOption) {
		var currentPageNodes = $('#clock-table').DataTable().rows({ page: 'current' }).nodes();
		$(currentPageNodes).each(function() {
			var node = $(this)
			var rowPlayerName = node.find('td:eq(4)').text();
			if (mapMarkerPlayerOption == false || mapMarkerPlayerOption && rowPlayerName == playerName)
			{
				var speed = Number(node.find('td:eq(2)').text());
				if (speed >= speedFilter){
					var id = parseInt(node.find('td:eq(6) button:last-child').prop('id'));
					idsArray.push(id);
				}
			}
		});
	} else {
		$('#clock-table').DataTable().rows().every(function() {
			var node = $(this.node())
			var rowPlayerName = node.find('td:eq(4)').text();
			if (mapMarkerPlayerOption == false || mapMarkerPlayerOption && rowPlayerName.trim() === playerName) {
				var speed = Number(node.find('td:eq(2)').text());
				if (speed >= speedFilter){
					var id = parseInt(node.find('td:eq(6) button:last-child').prop('id'));
					idsArray.push(id);
				}
			}
		});
	}
	hideMarkersExcept(databaseRecords, idsArray);
}

 
// update what markers should be shown
function filterMarkersBySpeed(dataList, speedFilter) {
	dataList.forEach(function(data) {
		if (Number(data.speed) > speedFilter) {
			if (data.marker) {
				data.marker.setMap(map);
			}
		} else {
			if (data.marker) {
				data.marker.setMap(null);
			}
		}
	});
}

 function hideMarkersExcept(dataList, activeMarkers) {
	for (let i = 0; i < dataList.length; i++) { 
		if (activeMarkers.includes(i)) {
			dataList[i].marker.setMap(map);
		} else {
			dataList[i].marker.setMap(null);
		}
	}
}

 function showAllMarkers(dataList) {
	for (let i = 0; i < dataList.length; i++) { 
		dataList[i].marker.setMap(map);
	}
}


// ==== PRINT VIEW ====
function openPrintView(element) {
    var elementRecord = databaseRecords[element.id];
	if ('serial' in elementRecord){
		$('#serial').text(elementRecord.serial);
	} else {
		var serial = generateSerial()
		databaseRecords[element.id].serial = serial
		$('#serial').text(serial);
	}
	
	$('#playerName').text(playerName);
	if(elementRecord.selfTestTimestamp != "00/00/0000 00:00") {
		$('#self-test-time').text(elementRecord.selfTestTimestamp);
		$('.testResult').addClass('pass');
		$('.testResult').text('PASS');
	} else {
		$('#self-test-time').text('N/A');
		$('.testResult').removeClass('pass');
		$('.testResult').text('N/A');
	}

	$('#recID').text(elementRecord.rid);
	$('#recDate').text(elementRecord.timestamp);
	$('#recSpeed').text(elementRecord.speed + ' mph');
	$('#recRange').text(elementRecord.range);
	$('#recStreet').text(elementRecord.street);
	
	openInfo(element);
	// open marker
	hideMarkersExcept(databaseRecords, [Number(element.id)]);
	// hide infowindow
	infowindow.close();
	$('.legend-wrapper').hide()
	
	// access Date
	const now = new Date();
	const formattedDateTime = now.toISOString().replace('T', ' ').replace(/\.\d{3}Z/, '').slice(0, 16);
	$('#printFooterDate').text(formattedDateTime);
	
	map.setOptions({
	  zoomControl: false,
	  fullscreenControl: false,
	});
	
	// copy map window
	setTimeout(function(){ 
		document.getElementById('printMap').innerHTML = document.getElementById('map').innerHTML;
		document.getElementById('printMap').style.cssText = "position: relative; width: 400px; height: 275px; overflow: hidden; margin: auto;";
		$('#view-record-container').fadeIn();
	}, 1000)
}

// MISC FUNCTIONS PRINTING
function generateSerial() {
    var characters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    var randCharIndex1 = Math.floor(Math.random() * characters.length);
    var randCharIndex2 = Math.floor(Math.random() * characters.length);
    var char1 = characters.charAt(randCharIndex1);
    var char2 = characters.charAt(randCharIndex2);

    var randNum1 = Math.floor(Math.random() * (99 - 10) + 10).toString();
    var randNum2 = Math.floor(Math.random() * (999 - 100) + 100).toString();

    var serial = '100'+char1+randNum1+char2+randNum2
    return serial
}

function captureScreenshot() {
	html2canvas(document.querySelector("#view-record"), {scale: '1.5'}).then(canvas => { 
		const imgData = canvas.toDataURL('image/png');
		var dataUrl = imgData.replace(/^data:image\/(png|jpg);base64,/, "");;
		uploadImageToImgur(dataUrl);
	});
}

function uploadImageToImgur(dataUrl) {
  var apiUrl = 'https://api.imgur.com/3/image';

  var headers = {
    'Authorization': imgurApiKey
  };

  var body = new FormData();
  body.append('image', dataUrl);

  fetch(apiUrl, {
    method: 'POST',
    headers: headers,
    body: body
  })
  .then(function(response) {
    if (response.ok) {
      response.json().then(function(data) {
        console.log('Image uploaded to Imgur. URL:', data.data.link);
		$('#copyButton').show();
		$('#copyButton').text("Copy to Clipboard");
		$('#dialogMsg').text("Uploaded Successfully");
		$('#urlDisplay').text(data.data.link);
		$('#print-result-dialog-container').fadeIn();
      });
    } else {
        console.log('Image failed to upload to Imgur', response.statusText);
		$('#copyButton').hide();
		$('#dialogMsg').text("Upload Failed");
		$('#urlDisplay').text(response.statusText);
		$('#print-result-dialog-container').fadeIn();
    }
  })
  .catch(function(error) {
        console.log('Image failed to upload to Imgur', response.statusText);
		$('#copyButton').hide();
		$('#dialogMsg').text("Upload Failed");
		$('#urlDisplay').text(error);
		$('#print-result-dialog-container').fadeIn();
  });
}
