var audioPlayer = null;
var soundID = 0;
var start;
var timerHandle;
var sniperscope = false
var clockVolume = 0.02; 
var calibrationVolume = 0.02; 
var jammingVolume = 0.02;

const context = new AudioContext();
var clockTone = createClockTone( context )
var clockToneMute;
var lasedHandle;
var played = false; 
var waiting = false;
$(document).ready(function(){
	$('#JammerDisplay').hide();
	$('#AdsDisplay').hide();
	$('#LidarDisplayContainer').hide();
    window.addEventListener('message', function(event) {
        if (event.data.action == 'SetLidarDisplayState') {
			if (event.data.state){
				$('#LidarDisplayContainer').show();
			} else{
				$('#LidarDisplayContainer').hide();
			}
		} else if (event.data.action == 'SetClockData') {
			$('#speed').text(event.data.speed);
			$('#range').text(event.data.range+'ft');
			$('#rangehud').text(event.data.range+'ft');
			$('#timer').text('');
			$('#lock').hide();
			clearInterval(timerHandle);
			if (event.data.towards == true){
				$('#arrowup').hide();
				$('#arrowdown').show();
				$('#speedhud').text('- '+event.data.speed);
				timer();
				clearInterval(clockToneMute);
				playClockTone();
			} else if (event.data.towards == false){
				$('#arrowup').show();
				$('#arrowdown').hide();
				$('#speedhud').text('+ '+event.data.speed);
				timer();
				clearInterval(clockToneMute);
				playClockTone();
			} else{
				$('#arrowup').hide();
				$('#arrowdown').hide();
				$('#speedhud').text('/ '+event.data.speed);
				clearInterval(clockToneMute);
				clockTone.vol.gain.exponentialRampToValueAtTime( 0.00001, context.currentTime + 0.1 );
			}
		} else if (event.data.action == 'SetDisplayMode') {
			if (event.data.mode == 'ADS') {
				$('#AdsDisplay').show()
				$('#LidarDisplayContainer').hide()
			} else{
				$('#AdsDisplay').hide()
				$('#LidarDisplayContainer').show()
			}
 		} else if (event.data.action == 'SetCalibrationState') {
			if (event.data.state) {
				clearInterval(timerHandle);
				$('#timer').text('');
				$('#MainContainer').show();
				$('#CalibrationContainer').hide();
				playSound('LidarCalibration', calibrationVolume)
			} else{
				clearInterval(timerHandle);
				timer();
				$('#MainContainer').hide();
				$('#CalibrationContainer').show();
			}	
		} else if (event.data.action == 'SetCalibrationProgress') {
			$('#calibrationprogress').text(event.data.progress);		
		} else if (event.data.action == 'ToggleScopeStyle') {
			if (event.data.sniperScope){
				$('#AdsDisplay').css("background-image", "url(textures/hud_sniper.png)");  
			} else {
				$('#AdsDisplay').css("background-image", "url(textures/hud_sight.png)");  
			}
			sniperscope = !sniperscope;
 		} else if (event.data.action == 'SetConfigVars') {
			calibrationVolume = event.data.calibrationSFX
			clockVolume = event.data.clockSFX
			jammingVolume = event.data.jammingSFX
		}	else if (event.data.action == 'SetJammerDisplayState'){
			if (event.data.state){
				$('#JammerDisplay').show();
			} else{
				$('#JammerDisplay').hide();
			}
		}	else if (event.data.action == 'SetJammerMode'){
			if (event.data.mode == 'idle'){
				$('#JammerDisplay').css("background-image", "url(textures/jammer.png)");  
			} else if (event.data.mode == 'green'){
				$('#JammerDisplay').css("background-image", "url(textures/jammer_green.png)");  
			} else if (event.data.mode == 'blue'){
				$('#JammerDisplay').css("background-image", "url(textures/jammer_blue.png)");  
			} else if (event.data.mode == 'red'){
				$('#JammerDisplay').css("background-image", "url(textures/jammer_red.png)");  
				lasedAudio();
			} 
		}
    });
});

 //Credit to xotikorukx playSound Fn.
function playSound(file, volume){
	if (audioPlayer != null) {
		audioPlayer.pause();
	}
	soundID++;

	audioPlayer = new Audio("./sounds/" + file + ".ogg");
	audioPlayer.volume = volume;
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
	$('#lock').show();
	$('#timer').show();
	timerHandle = setInterval(function() {
		delta = Date.now() - start; // milliseconds elapsed since start
		$('#timer').text(delta.toString().toHHMMSS());
		$('#calibrationtimer').text(delta.toString().toHHMMSS());
	}, 500); // update about every second
}

function lased(color){
	$('#JammerDisplayLarge').css("background-image", "url(textures/jammer_red.png)");  
	lasedHandle = setInterval(function(color) {
		$('#JammerDisplay').css("background-image", "url(textures/jammer.png)");  
	}, 100); // update about every second
}

function lasedAudio(){
	if (!played){
		played = true;
		playSound('LaserAlert', jammingVolume)
	}
	if (!waiting){
		waiting = true
		console.log('setting')
		lasedHandle = setInterval(function() {
			played = false;
			waiting = false;
			console.log('resetting')
		}, 10000); // update about every second
	}
}

function playClockTone(){
	clockTone.osc.frequency.exponentialRampToValueAtTime( 2300, context.currentTime + 0.1 );
	clockTone.vol.gain.exponentialRampToValueAtTime( clockVolume, context.currentTime + 0.01 );
	clockToneMute = setInterval(function() {
		clockTone.vol.gain.exponentialRampToValueAtTime( 0.00001, context.currentTime + 0.1 );
	}, 100); // update about every second
}


