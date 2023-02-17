var audioPlayer = null;
var soundID = 0;
var start;
var timerHandle;
var sniperscope = false
var clockVolume = 0.02; 
var calibrationVolume = 0.02; 
const context = new AudioContext();
var clockTone = createClockTone( context )
var clockToneMute;
var speedAlert = false;

$(document).ready(function(){
	$('#hud').hide();
	$('#lasergun').hide();
	$('#history-container').hide();
	$('#fast-container').hide();

    window.addEventListener('message', function(event) {
        if (event.data.action == 'SetLidarDisplayState') {
            $('#lasergun').show();
			if (event.data.state){
				$('#lasergun').show();
			} else{
				$('#lasergun').hide();
			}
		} else if (event.data.action == 'SendClockData') {
			$('#speed').text(event.data.speed);
			$('#range').text(event.data.range+'ft');
			$('#rangehud').text(event.data.range+'ft');
			$('#timer').text('');
			$('#lock').hide();
			$('#arrowup').hide();
			$('#arrowdown').hide();
			clearInterval(timerHandle);
			if (event.data.towards == true){
				$('#speedhud').text('- '+event.data.speed);
				$('#arrowup').hide();
				$('#arrowdown').show();
				timer();
				clearInterval(clockToneMute);
				if (!speedAlert){
					playClockTone();
				}
			} else if (event.data.towards == false){
				$('#speedhud').text('+ '+event.data.speed);
				$('#arrowdown').hide();
				$('#arrowup').show();
				timer();
				clearInterval(clockToneMute);
				if (!speedAlert){
					playClockTone();
				}
			} else{
				$('#speedhud').text('/ '+event.data.speed);
				clearInterval(clockToneMute);
				clockTone.vol.gain.exponentialRampToValueAtTime( 0.00001, context.currentTime + 0.1 );
			}
		} else if (event.data.action == 'SetDisplayMode') {
			if (event.data.mode == 'ADS') {
				$('#hud').show()
				$('#lasergun').hide()
			} else{
				$('#hud').hide()
				$('#lasergun').show()
			}
 		} else if (event.data.action == 'SendCalibrationState') {
			if (event.data.state) {
				$('#lidar-home').show();
				$('#calibration-container').hide();
				if (event.data.sound) {
					playSound('LidarCalibration')
				}
				clearInterval(timerHandle);
			} else{
				$('#lidar-home').hide();
				$('#calibration-container').show();
				clearInterval(timerHandle);
				timer();
			}	
		} else if (event.data.action == 'SendCalibrationProgress') {
			$('#calibrationprogress').text(event.data.progress);		
		} else if (event.data.action == 'scopestyle') {
			if (sniperscope){
				$('#hud').css("background-image", "url(textures/hud_sight.png)");  
			} else {
				$('#hud').css("background-image", "url(textures/hud_sniper.png)");  
			}
			sniperscope = !sniperscope;
 		} else if (event.data.action == 'SetConfigVars') {
			calibrationVolume = event.data.calibrationSFX
			clockVolume = event.data.clockSFX
		} else if (event.data.action == 'SetHistoryState') {
			// if (!$('#fast-container').is(":visible")) {
				if (event.data.state){
					$('#lidar-home').hide();
					$('#history-container').show();
				} else {
					$('#lidar-home').show();
					$('#history-container').hide();
				}
			// }
		} else if (event.data.action == 'SendHistoryData') {
			$('#counter').text(event.data.counter);
			$('#timestamp').text("Date Time: " + event.data.time);
			$('#clock').text("Speed Range: " + event.data.clock);
		} else if (event.data.action == 'PlayButtonPressBeep') {
			playSound(event.data.file);
		/*
		} else if (event.data.action == 'SetFastSpeedState') {
			if (event.data.state){
				$('#fast-container').show();
				$('#lidar-home').hide();
			} else {
				$('#fast-container').hide();
				$('#lidar-home').show();
			}
		} else if (event.data.action == 'SendFastLimit') {
			$('#fast-alert').text(event.data.speed + ' mph');
		 } else if (event.data.action == 'PlayFastAlertBeep') {
			if (!speedAlert){
				playSound(event.data.file);
			}
			speedAlert = true;
			setTimeout(function() {speedAlert = false}, 2000);
		*/
		} else if (event.data.action == 'SendBatteryAmount') {
			$('#battery').attr('src', 'textures/battery' + event.data.bars + '.png');
		}
    });
});

 //Credit to xotikorukx playSound Fn.
function playSound(file){
	if (audioPlayer != null) {
		audioPlayer.pause();
	}
	soundID++;

	audioPlayer = new Audio("./sounds/" + file + ".ogg");
	audioPlayer.volume = calibrationVolume;
	var didPlayPromise = audioPlayer.play();

	if (didPlayPromise === undefined) {
		audioPlayer = null; //The audio player crashed. Reset it so it doesn't crash the next sound.
	} else {
		didPlayPromise.then(_ => { }).catch(error => { //This does not execute until the audio is playing.
			audioPlayer = null; //The audio player crashed. Reset it so it doesn't crash the next sound.
		})
	}
}

function createClockTone( audioContext ){
	let osc = audioContext.createOscillator();
	let vol = audioContext.createGain();

	osc.type = "sine";
	osc.frequency.value = 0.5;
	vol.gain.value = 0.02; 
	osc.connect( vol );
	vol.connect( audioContext.destination );
	osc.start( 0 );
	return { osc: osc, vol: vol }
}


String.prototype.toHHMMSS = function () {
    var sec_num = parseInt(this, 10); // don't forget the second param
    var minutes = Math.floor(sec_num / 60000);
    var seconds = Math.floor((sec_num - (minutes * 60000)) / 1000);

    if (minutes < 10) {minutes = "0"+minutes;}
    if (seconds < 10) {seconds = "0"+seconds;}
    return minutes+':'+seconds;
}

function timer(){
	start = Date.now();
	timerHandle = setInterval(function() {
		delta = Date.now() - start; // milliseconds elapsed since start
		$('#lock').show();
		$('#timer').show();
		$('#timer').text(delta.toString().toHHMMSS());
		$('#calibrationtimer').text(delta.toString().toHHMMSS());
	}, 500); // update about every second
}

function playClockTone(){
	clockTone.osc.frequency.exponentialRampToValueAtTime( 2300, context.currentTime + 0.1 );
	clockTone.vol.gain.exponentialRampToValueAtTime( clockVolume, context.currentTime + 0.01 );
	clockToneMute = setInterval(function() {
		clockTone.vol.gain.exponentialRampToValueAtTime( 0.00001, context.currentTime + 0.1 );
	}, 100); // update about every second
}


