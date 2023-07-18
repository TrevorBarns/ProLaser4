// LIDAR
var lidarOsd;
var context = new AudioContext();
var clockTone = createClockTone(context);
var audioPlayer = null;
var timerHandle;
var timerDelta;
var sniperscope = false;
var clockVolume = 0.02;
var selfTestVolume = 0.02;
var recordLimit = -1
var version = -1
var clockToneMute;
var databaseRecords = [];
var resourceName;
var velocityUnit = 'mph'
var rangeUnit = 'ft'
var speedFilters = []
const imperialSpeedFilters = [0, 20, 30, 40, 50, 60, 70, 80, 90, 100];
const metricSpeedFilters = [0, 20, 40, 60, 80, 100, 120, 140, 160, 180];
var moveMode = false;
var initWidth = 1920;
var initHeight = 1080;
var lastTop = 0;
var lastLeft = 0;

// TABLET
var infowindow;
var mapOptions;
var roadmap;
var map;
var dataTable;
var speedLimits = {};
var playerName;
var imgurApiKey;
var discordApiKey;
var speedFilter = 0;
var mapMarkerPageOption = true
var mapMarkerPlayerOption = false
var legendWrapper;
var currentRecord;
var themeMode = 0; // 0-light, 1-dark, 2-auto
var tabletTime;
var gameTime;
var timeDisplayHandle;
const darkTime = new Date("1970-01-01T21:30:00");
const lightTime = new Date("1970-01-01T06:15:00");

// Dynamically load map element ensuring no GM API race condition
window.initMap = initMap;

// Fetch speedlimits json for color coding and filtering.
fetch('../../speedlimits.json')
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
		sendDataToLua('CloseTablet', undefined);
		$('#loading-dialog-container').hide();	
		$('#view-record-container').hide();
		$('#print-result-dialog-container').hide();		
	}
} );
 
$(document).ready(function () {
// Dynamically load script once doc is ready.
	var googleMapsApiScript = document.createElement('script');
	googleMapsApiScript.src = 'https://maps.googleapis.com/maps/api/js?key=AIzaSyDF6OI8FdmtZmgrTsh1yTa__UlwA52BGEQ&callback=initMap';
	googleMapsApiScript.async = true;
	document.head.appendChild(googleMapsApiScript);

		
	lidarOsd = document.getElementById("laser-gun");
	initWidth = document.body.clientWidth;
	initHeight = document.body.clientHeight;
    $('#hud').hide();
    $('#laser-gun').hide();
    $('#history-container').hide();
    $('#tablet').hide();
    $('#loading-dialog-container').hide();
	$('#view-record-container').hide();
	$('#print-result-dialog-container').hide();
	$('#tablet-close').click(function() { 
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
				  '<th class="speed">Speed<br>(' + velocityUnit + ')</th>' +
				  '<th class="distance">Distance<br>(' + rangeUnit + ')</th>' +
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
		sendDataToLua('CloseTablet', undefined);
	});	
	
	$('#toggle-theme').click(function() { 
		if (themeMode == 0) {
			themeMode = 1;
		} else if(themeMode == 1) {
			themeMode = 2;
		} else {
			themeMode = 0;
		}
		RefreshTheme();
		sendDataToLua('SendTheme', themeMode);
	});
	
	$('#print-view-print').click( function() { 
		if (imgurApiKey != '' || discordApiKey != ''){
			$('#tablet').fadeOut();
			$('.print-view-header').css('opacity', '0');
			$('#view-record').addClass('no-border');
			captureScreenshot();
			setTimeout(function(){
				$('#tablet').fadeIn();
				$('.print-view-header').css('opacity', '1');
				$('#view-record').removeClass('no-border');
			}, 1000)
		} else {
			$('#copy-button').hide();
			$('#dialog-msg').text("<h6>Upload Failed</h6>");
			$('#url-display-imgur').text("No Imgur or Discord integration set. Contact a server developer.");
			$('#print-result-dialog-container').fadeIn();
		}
	});
	
	$('#print-view-close').click( function() { 
		map.setOptions({
		  zoomControl: true,
		});
		$('#view-record-container').fadeOut();
		$('.legend-wrapper').show();
		updateMarkers();
	});
	
	$('#copy-button').click(function() {
		var urlDisplay = $('#url-display-discord').text();
		if (urlDisplay === '') {
			urlDisplay = $('#url-display-imgur').text();
		}
		
		urlDisplay = urlDisplay.split(' ')[1];
		
		var textarea = document.createElement('textarea');
		textarea.value = urlDisplay;
		document.body.appendChild(textarea);
		textarea.select();
		document.execCommand('copy');
		document.body.removeChild(textarea);

		$('#copy-button').text("Link Copied");
	});

	
	$('#print-dialog-close').click( function() { 
		$('#print-result-dialog-container').fadeOut();
	});
		
    window.addEventListener('message', function (event) {
        if (event.data.action == 'SetLidarDisplayState') {
            if (event.data.state) {
                $('#laser-gun').fadeIn();
            } else {
                $('#laser-gun').fadeOut();
            }
        } else if (event.data.action == 'SendClockData') {
            $('#speed').text(event.data.speed);
            $('#range').text(event.data.range + rangeUnit);
            $('#range-hud').text(event.data.range + rangeUnit);
            $('#timer').text('');
            $('#lock').hide();
            $('#arrowup').hide();
            $('#arrowdown').hide();
            if (event.data.towards == true) {
                $('#speed-hud').text('- ' + event.data.speed);
                $('#arrowup').hide();
                $('#arrowdown').show();
                timer();
                clearInterval(clockToneMute);
				playClockTone();
            } else if (event.data.towards == false) {
                $('#speed-hud').text('+ ' + event.data.speed);
                $('#arrowdown').hide();
                $('#arrowup').show();
                timer();
                clearInterval(clockToneMute);
				playClockTone();
            } else {
                $('#speed-hud').text('/ ' + event.data.speed);
                clearInterval(clockToneMute);
                clockTone.vol.gain.exponentialRampToValueAtTime(0.00001,context.currentTime + 0.1);
				clearInterval(timerHandle);
            }
        } else if (event.data.action == 'SetDisplayMode') {
            if (event.data.mode == 'ADS') {
                $('#hud').show();
                $('#laser-gun').hide();
            } else {
                $('#hud').hide();
                $('#laser-gun').show();
            }
        } else if (event.data.action == 'SetSelfTestState') {
            if (event.data.state) {
				clearInterval(timerHandle);
				$('#timer').text('');
				$('#lock').hide();
                $('#lidar-home').show();
                $('#self-test-container').hide();
                if (event.data.sound) {
                    playSound('LidarCalibration');
                }
            } else {
                $('#lidar-home').hide();
                $('#self-test-container').show();
				$('#self-test-timer').show();
                timer();
            }
        } else if (event.data.action == 'SendSelfTestProgress') {
            $('#self-test-progress').text(event.data.progress);
			if (event.data.stopTimer){
				$('#self-test-timer').hide();
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
			discordApiKey = event.data.discordApiKey;
			recordLimit = event.data.recordLimit;
			resourceName = event.data.name;
			version = event.data.version;
			$('#tablet-version').text('v'+version);
			themeMode = event.data.theme;
			RefreshTheme();
			if (event.data.osdStyle != false){
				event.data.osdStyle = JSON.parse(event.data.osdStyle);
				$('#laser-gun').css("left", event.data.osdStyle.left);
				$('#laser-gun').css("top", event.data.osdStyle.top);
				$('#laser-gun').css("transform", 'scale('+event.data.osdStyle.scale+')');
			}
			if (event.data.metric) {
				speedFilters = metricSpeedFilters;
				velocityUnit = 'km/h';
				rangeUnit = 'm';
				$('#unit').text(velocityUnit)
				$('.speed').html('Speed<br>(' + velocityUnit + ')')
				$('.distance').html('Distance<br>(' + rangeUnit + ')')
			} else {
				speedFilters = imperialSpeedFilters;
				velocityUnit = 'mph';
				rangeUnit = 'ft';
			}
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
				returnData.range = $('#range').text().replace(rangeUnit, '');
				if ($('#arrowup').is(':visible')){
					returnData.arrow = 1;
				} else if ($('#arrowdown').is(':visible')) {
					returnData.arrow = -1;
				} else {
					returnData.arrow = 0;
				}
				returnData.elapsedTime = timerDelta;
				returnData.battery = $('#battery').attr('src');
			}
			sendDataToLua('ReturnCurrentDisplayData', returnData);
		} else if (event.data.action == 'SendPeersDisplayData') {
			$('#speed').text(event.data.speed);
            $('#range').text(event.data.range + rangeUnit);
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
			if (event.data.range != '----' + rangeUnit) {
				timer(event.data.elapsedTime);
			}
        } else if (event.data.action == 'SendDatabaseRecords') {
			playerName = event.data.name;
			
			// clock display
			updateClock();
			timeDisplayHandle = setInterval(updateClock, 60000);
			
			databaseRecords = JSON.parse(event.data.table);
			updateTabletWindow(playerName, databaseRecords);
			
			// time based night mode handling
			gameTime = date = new Date("1970-01-01");
			const [hours, minutes, seconds] = event.data.time.split(":");
			date.setFullYear(1970, 0, 1);
			gameTime.setHours(hours);
			gameTime.setMinutes(minutes);
			if (themeMode == 2) {
				if (gameTime > darkTime || gameTime < lightTime) {
					$("#theme").attr("href", "dark.css");
				} else {
					$("#theme").attr("href", "");
				}
			}
        } else if (event.data.action == 'SetTabletState') {
            if (!event.data.state) {
                $('#tablet').fadeOut();
				clearInterval(timeDisplayHandle);
            }  
		} else if (event.data.action == 'SendResizeAndMove') {
			if (event.data.reset) {
				lidarOsd.style.top = "unset";
				lidarOsd.style.bottom = "2%";
				lidarOsd.style.left = "60%";
				lidarOsd.style.transform = "scale(0.65)";
				ReturnOsdStyle()
			} else {
				lidarOsd.addEventListener("wheel", handleScrollResize);
				lidarOsd.addEventListener("mousedown", dragMouseDown);
				moveMode = true;
				$('#laser-gun').css('pointer-events', 'all');
			}
		}
    });
});


// ======= MAIN SCRIPT =======
// This function is used to send data back through to the LUA side 
function sendDataToLua( name, data ) {
	$.post( "https://"+ resourceName +"/" + name, JSON.stringify( data ), function( datab ) {
		if ( datab != "ok" ) {
			console.log( datab );
		}            
	} );
}

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
    var sec_num = parseInt(this, 10);
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

function timer( elapsedTime = 0 ) {
	var start = Date.now() - elapsedTime
	clearInterval(timerHandle);
    timerHandle = setInterval(function () {
        timerDelta = Date.now() - start; // milliseconds elapsed since start
        $('#lock').show();
        $('#timer').show();
        $('#timer').text(timerDelta.toString().toHHMMSS());
        $('#self-test-timer').text(timerDelta.toString().toHHMMSS());
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


// Move Mode
// Drag to move functions below.
// Exit HUD Move Mode 
$(document).keyup(function(event) {
	if (moveMode) {
		//					Esc				Backspace				Space
		if (event.keyCode == 27 || event.keyCode == 9 || event.keyCode == 32) {
			ReturnOsdStyle();
		}
	}
} );

$(document).contextmenu(function() {
	if (moveMode) {
		ReturnOsdStyle();
	}
} );

function ReturnOsdStyle() {
	var computedStyles = window.getComputedStyle(lidarOsd);
	var left = computedStyles.getPropertyValue("left");
	var top = computedStyles.getPropertyValue("top");
	var transform = computedStyles.transform;
	var newScale = 0.65; 

	if (transform && transform !== "none") {
	  var matrixMatch = transform.match(/^matrix\((.+)\)$/);
	  if (matrixMatch && matrixMatch.length > 1) {
		var matrixValues = matrixMatch[1].split(", ");
		var scale = parseFloat(matrixValues[0]);
		if (!isNaN(scale)) {
			newScale = scale
		}
	  }
	}

	sendDataToLua( "ReturnOsdScaleAndPos", data = { left: left, top: top, scale: newScale } );
	moveMode = false;
	$('#laser-gun').css('pointer-events', 'none');
}

function dragMouseDown(e) {
  e = e || window.event;
  e.preventDefault();
  // get the mouse cursor position at startup:
  pos3 = e.clientX;
  pos4 = e.clientY;
  document.onmouseup = closeDragElement;
  // call a function whenever the cursor moves:
  document.onmousemove = elementDrag;
}

function elementDrag(e) {
  e = e || window.event;
  e.preventDefault();
  // calculate the new cursor position:
  pos1 = pos3 - e.clientX;
  pos2 = pos4 - e.clientY;
  pos3 = e.clientX;
  pos4 = e.clientY;
  // set the element's new position:
  lidarOsd.style.top = (lidarOsd.offsetTop - pos2) + "px";
  lidarOsd.style.left = (lidarOsd.offsetLeft - pos1) + "px";
}

function closeDragElement() {
  // stop moving when mouse button is released:
  document.onmouseup = null;
  document.onmousemove = null;
}

function handleScrollResize(event) {
  var currentScale = parseFloat($(lidarOsd).css("transform").replace("matrix(", "").split(",")[0]);
  
  if (isNaN(currentScale)) {
    console.log("Scale not previously set on " + lidarOsd.id + ", using 1.0");
    currentScale = 0.65;
  }
  
  var deltaY = Math.sign(event.deltaY);
  var newScale = currentScale + (deltaY < 0 ? 0.05 : -0.05);
  
  if (newScale < 0.3) {
    newScale = 0.3;
  } else if (newScale > 1.0){
	  newScale = 1.0;
  }

  $(lidarOsd).css("transform", "scale(" + newScale + ")");
}

// Handle Resolution Changes -> Restore Position
$(window).resize(function() {
	if (document.body.clientWidth != initWidth || document.body.clientHeight != initHeight) {
		lastTop = lidarOsd.style.top;
		lastLeft = lidarOsd.style.left;
		lidarOsd.style.top = "unset";
		lidarOsd.style.bottom = "2%";
		lidarOsd.style.left = "60%";
		sendDataToLua( "ResolutionChange", data = { restore: false } );
	} else {
		lidarOsd.style.top = lastTop;
		lidarOsd.style.left = lastLeft;
		sendDataToLua( "ResolutionChange", data = { restore: true } );
	}

});
// ===== END MAIN SCRIPT ======

// ========= TABLET =========

function initMap(){
	infowindow = new google.maps.InfoWindow()
	mapOptions = {
		center: new google.maps.LatLng(0, 0),
		zoom: 2,
		minZoom: 2,
		streetViewControl: false,
		mapTypeControl: false,
		gestureHandling: 'greedy',
	 };

	// Define our custom map type
	roadmap = new google.maps.ImageMapType({
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
	
	 // ---------------------
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
					{ icon: 'textures/map/red-dot-light.png', label: '> Speedlimit by 10 ' + velocityUnit +'+' },
					{ icon: '', label: '<div class="legend-spacer" style="margin-top: -8px;">Peers</div>' },
					{ icon: 'textures/map/green-dot.png', label: '< Speedlimit' },
					{ icon: 'textures/map/yellow-dot.png', label: '> Speedlimit' },  
					{ icon: 'textures/map/red-dot.png', label: '> Speedlimit by 10 ' + velocityUnit + '+' } ];

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
}


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
			databaseRecords[i].speedlimit = speedLimit;
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
		record.infoContent = '<div class="marker-label"><b>RID: <a href="#" onclick="retrieveRecordFromMarker(\'' + record.rid + '\')">' + record.rid + '</a></b><br>' + record.speed + velocityUnit + '<br>' + record.player + '</div>';
		
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
			'<td class="mapping"><button class="table-btn" id=' + i +' onClick="openInfo(this)"><i class="fa-sharp fa-solid fa-map-location-dot"></i></button></td>' +
			'<td class="print"><button class="table-btn" id=' + i +' onClick="openPrintView(this)"><i class="fa-sharp fa-solid fa-print"></i></button></td></tr>'
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
	
	// Table speed filter handling, Drop down creation.
	var speedFilterDropdown = '<div class="dropdown" style="float: left !important;">' +
			'<button class="btn btn-default dropdown-toggle" type="button" data-toggle="dropdown" style="height: 27px; line-height: 6px;">' +
			'<i class="fa-solid fa-filter"></i> Speed Filter <span class="caret"></span></button>' +
			'<ul class="dropdown-menu">';
	for (var i = 0; i < speedFilters.length; i++) {
	  speedFilterDropdown += '<li><a href="#" value="' + speedFilters[i] + '" class="text-center">' + speedFilters[i] + velocityUnit + '</a></li>';
	}
	speedFilterDropdown += '</ul></div>';
	$('#clock-table_filter').append(speedFilterDropdown);


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
    currentRecord = databaseRecords[element.id];
	if ('serial' in currentRecord){
		$('#serial').text(currentRecord.serial);
	} else {
		var serial = generateSerial()
		databaseRecords[element.id].serial = serial
		$('#serial').text(serial);
	}
	
	$('#playerName').text(currentRecord.player);
	if(currentRecord.selfTestTimestamp != "00/00/0000 00:00") {
		$('#self-test-time').text(currentRecord.selfTestTimestamp);
		$('.testResult').addClass('pass');
		$('.testResult').text('PASS');
	} else {
		$('#self-test-time').text('N/A');
		$('.testResult').removeClass('pass');
		$('.testResult').text('N/A');
	}

	$('#recID').text(currentRecord.rid);
	$('#recDate').text(currentRecord.timestamp);
	$('#recSpeed').text(currentRecord.speed + ' ' + velocityUnit);
	$('#recRange').text(currentRecord.range + ' ' + rangeUnit);
	$('#recStreet').text(currentRecord.street);
	
	openInfo(element);
	// open marker
	hideMarkersExcept(databaseRecords, [Number(element.id)]);
	// hide infowindow
	infowindow.close();
	$('.legend-wrapper').hide()
	
	// access Date
	const now = new Date();
	const formattedDateTime = now.toISOString().replace('T', ' ').replace(/\.\d{3}Z/, '').slice(0, 16);
	$('#print-footer-date').text(formattedDateTime);
	
	map.setOptions({
	  zoomControl: false,
	  fullscreenControl: false,
	});
	
	// copy map window
	setTimeout(function(){ 
		document.getElementById('print-map').innerHTML = document.getElementById('map').innerHTML;
		document.getElementById('print-map').style.cssText = "position: relative; width: 400px; height: 275px; overflow: hidden; margin: auto;";
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
		if (imgurApiKey != ''){
			var dataUrl = imgData.replace(/^data:image\/(png|jpg);base64,/, "");
			uploadImageToImgur(dataUrl);
		} 
		if (discordApiKey != ''){
			uploadImageToDiscord(imgData);
		}
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
		$('#copy-button').show();
		$('#copy-button').text("Copy to Clipboard");
		$('#dialog-msg').html("<h6>Uploaded Successfully</h6>");
		$('#url-display-imgur').html('<b><u>Imgur:</u></b> ' + data.data.link);
		$('#print-result-dialog-container').fadeIn();
      });
    } else {
        throw new Error('Failed to upload image. Status: ' + response.status);
    }
  })
  .catch(function(error) {
        console.log('Image failed to upload to Imgur', response.statusText);
		$('#copy-button').hide();
		$('#dialog-msg').text("<h6>Upload Failed</h6>");
		$('#url-display-imgur').html('<b><u>Imgur:</u></b> ' + error);
		$('#print-result-dialog-container').fadeIn();
  });
}

function uploadImageToDiscord(dataUrl) {
  // Convert the base64 image data to a Blob object
  var byteString = atob(dataUrl.split(',')[1]);
  var mimeType = dataUrl.split(',')[0].split(':')[1].split(';')[0];
  var arrayBuffer = new ArrayBuffer(byteString.length);
  var uint8Array = new Uint8Array(arrayBuffer);
  for (var i = 0; i < byteString.length; i++) {
    uint8Array[i] = byteString.charCodeAt(i);
  }
  var blob = new Blob([arrayBuffer], { type: mimeType });

  // Create a FormData object
  var formData = new FormData();
  formData.append('file', blob, 'record-' + currentRecord.rid + '.png');
  
  const now = new Date();
  const formattedDateTime = now.toISOString().replace('T', ' ').replace(/\.\d{3}Z/, '').slice(0, 16);

  var embedData = {	
    color: 11730954,
    title: 'Speed Event Record',
    description: '',
    fields: [
      {
        name: '',
        value: '-------------------------------------------------------------------------------------',
		inline: false,
      },
      {
        name: 'RID:',
        value: currentRecord.rid,
		inline: true,
      },   
	  {
        name: 'Timestamp:',
        value: currentRecord.timestamp,
		inline: true,
      },
      {
        name: 'User:',
        value: currentRecord.player,
		inline: true,
      },
      {
        name: 'Est. Speed:',
        value: currentRecord.speed + ' ' + velocityUnit,
		inline: true,
      },
      {
        name: 'Est. Distance:',
        value: currentRecord.range + ' ' + rangeUnit,
		inline: true,
      },
      {
        name: 'Est. Geo Location:',
        value: currentRecord.street,
		inline: true,
      },
      {
        name: 'Est. Speed Limit:',
        value: currentRecord.speedlimit + ' ' + velocityUnit,
		inline: true,
      },
	  {
        name: '',
        value: '-------------------------------------------------------------------------------------',
		inline: false,
      },
    ],
    image: {
      url: 'attachment://record-' + currentRecord.rid + '.png',
    },
    footer: {
      text: 'Accessed: ' + formattedDateTime,
    },
  };

  formData.append('payload_json', JSON.stringify({
    username: 'ProLaser4',
    avatar_url: 'https://i.imgur.com/YY12jV8.png',
    content: '',
    embeds: [embedData],
  }));

  formData.append('file', blob, 'record.png');

  fetch(discordApiKey, {
    method: 'post',
    body: formData,
  })
  .then(function(response) {
    if (response.ok) {
      response.json().then(function(data) {
		if (data.embeds && data.embeds.length > 0 && data.embeds[0].image && data.embeds[0].image.url){
			console.log('attachment found')
			console.log('Image uploaded to Discord. URL:', data.embeds[0].image.url);
			$('#copy-button').show();
			$('#copy-button').text("Copy to Clipboard");
			$('#dialog-msg').text("<h6>Uploaded Successfully</h6>");
			$('#url-display-discord').html('<b><u>Discord:</u></b> ' + data.embeds[0].image.url);
			$('#print-result-dialog-container').fadeIn();
		}
      });
    } else {
        throw new Error('Failed to upload image. Status: ' + response.status);
    }
  })
  .catch(function(error) {
        console.log('Image failed to upload to Discord', response.statusText);
		$('#copy-button').hide();
		$('#dialog-msg').text("<h6>Upload Failed</h6>");
		$('#url-display-discord').html('<b><u>Discord:</u></b> ' + error);
		$('#print-result-dialog-container').fadeIn();
  });
}


function retrieveRecordFromMarker(text) {
	if ($('#clock-table').DataTable().search() == ''){
		$('#clock-table').DataTable().search(text).draw();
	} else {
		$('#clock-table').DataTable().search('').draw();
	}
}

function RefreshTheme(){
	if (themeMode == 0) {
		$("#theme").attr("href", "");
		$("#theme-text").text(' D');
	} else if(themeMode == 1) {
		$("#theme").attr("href", "dark.css");
		$("#theme-text").text(' N')
	} else {
		if (gameTime && darkTime && lightTime){
			if (gameTime > darkTime || gameTime < lightTime) {
				$("#theme").attr("href", "dark.css");
			} else {
				$("#theme").attr("href", "");
			}
		}
		$("#theme-text").text(' A')				
	}
}

function updateClock() {
	var dateTimeElement = document.getElementById('date-time');
	var currentTime = new Date();
	// Extract the individual components
	var month = currentTime.getUTCMonth() + 1; // Months are zero-based
	var day = currentTime.getUTCDate();
	var year = currentTime.getUTCFullYear();
	var hours = currentTime.getUTCHours();
	var minutes = currentTime.getUTCMinutes();

	// Add leading zeros if necessary
	day = day < 10 ? '0' + day : day;
	hours = hours < 10 ? '0' + hours : hours;
	minutes = minutes < 10 ? '0' + minutes : minutes;

	// Create the formatted date-time string
	var dateTimeString = month + '/' + day + '/' + year + ' ' + hours + ':' + minutes;
	dateTimeElement.textContent = dateTimeString;
}