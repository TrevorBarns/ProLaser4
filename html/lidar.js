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

$(document).ready(function(){
	$('#hud').hide();
	$('#lasergun').hide();
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
			clearInterval(timerHandle);
			if (event.data.towards == true){
				$('#speedhud').text('- '+event.data.speed);
				timer();
				clearInterval(clockToneMute);
				playClockTone();
			} else if (event.data.towards == false){
				$('#speedhud').text('+ '+event.data.speed);
				timer();
				clearInterval(clockToneMute);
				playClockTone();
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
				$('#left').show();
				$('#right').show();
				$('#verticaldiv').show();
				$('#timer').text('');
				$('#calibration').hide();
				$('#calibrationprogress').hide();
				$('#calibrationtimer').hide();
				playSound('LidarCalibration')
				clearInterval(timerHandle);
			} else{
				$('#left').hide();
				$('#right').hide();
				$('#verticaldiv').hide();
				$('#calibration').show();
				$('#calibrationprogress').show();
				$('#calibrationtimer').show();
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
			console.log(clockVolume)
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


