package kheftel.util
{
	import flash.desktop.NativeApplication;
	import flash.events.Event;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.system.Capabilities;

	/**
	 * Auto-pauses self on Android when app loses focus.  Allows sound to be paused and resumed at the same place.  
	 * Only allows one instance of sound to play at a time.
	 */
	public class PauseableSound
	{
		private static const NAME:String = 'PauseableSound';
		
		private var _sound:Sound;
		private var _channel:SoundChannel;
		private var _position:Number;
		private var _transform:SoundTransform;
		private var _paused:Boolean;
		private var _loop:Boolean;
		private var _verbose:Boolean;
		
		/**
		 * creates a new PauseableSound
		 * @param s the flash sound to encapsulate.
		 */
		public function PauseableSound(s:Sound, verbose:Boolean = true)
		{
			if(s == null) throw new ArgumentError('sound cannot be null');
			
			_verbose = verbose;
			_sound = s;
			_position = 0;
			_transform = new SoundTransform();
			_paused = false;
			_loop = false;
			_channel = null;
			
			// auto-pause and resume the sound on Android so sounds don't play in the background after app loses focus
			if(Capabilities.manufacturer.indexOf("Android") != -1)
			{
				NativeApplication.nativeApplication.addEventListener(flash.events.Event.ACTIVATE, onActivate, false, 0, true);
				NativeApplication.nativeApplication.addEventListener(flash.events.Event.DEACTIVATE, onDeactivate, false, 0, true);
			}
		}
		
		private function log(msg:String):void
		{
			if(_verbose)
				trace('[' + NAME + ']: ' + msg);
		}
		
		public function get paused():Boolean
		{
			return _paused;
		}
		
		public function get playing():Boolean
		{
			return _channel != null;
		}

		/**
		 * must be called when you're done with the sound to dispose resources
		 */
		public function dispose():void
		{
			log('dispose');
			
			stop();
			if(Capabilities.manufacturer.indexOf("Android") != -1)
			{
				NativeApplication.nativeApplication.removeEventListener(flash.events.Event.ACTIVATE, onActivate);
				NativeApplication.nativeApplication.removeEventListener(flash.events.Event.DEACTIVATE, onDeactivate);
			}
		}
		
		/**
		 * pauses the sound
		 */
		public function pause():void
		{
			log('pause');
			if(_channel)
			{
				log('channel was non-null');
				_position = _channel.position;
				_channel.stop();
				_channel = null;
				_paused = true;
			}
		}
		
		/**
		 * resumes a sound if it was paused, if not, does nothing
		 */
		public function resume():void
		{
			if(!_paused) return;
			
			log('resume');
			
			_channel = _sound.play(_position, _loop ? int.MAX_VALUE : 0, _transform);
			_channel.addEventListener(flash.events.Event.SOUND_COMPLETE, onComplete, false, 0, true);
			_paused = false;
		}
		
		/**
		 * stops sound, resets to beginning
		 */
		public function stop():void
		{
			log('stop');
			if(_channel)
			{
				log('channel was non-null');
				_channel.stop();
				_position = 0;
				_channel = null;
			}
		}
		
		/**
		 * plays a sound
		 * @param volume the volume to play the sound at
		 * @param loop whether to loop the sound continuously
		 * @param pan the panning to apply to the sound
		 * @param startTime offset in milliseconds from the start of the sound to start playing at
		 */
		public function play(volume:Number = 1, loop:Boolean = false, pan:Number = 0, startTime:Number = 0):void
		{
			log('play');
			
			// only allow one instance of the sound to play at a time
			if(_channel)
			{
				log('channel was non-null');
				_channel.stop();
				_channel = null;
				_position = 0;
			}
			
			_paused = false;
			_transform.volume = volume;
			_transform.pan = pan;
			_loop = loop;
			_position = startTime;
			_channel = _sound.play(_position, loop ? int.MAX_VALUE : 0, _transform);
			_channel.addEventListener(flash.events.Event.SOUND_COMPLETE, onComplete, false, 0, true);
		}
		
		private function onComplete(e:*):void
		{
			log('onComplete');
			
			if(!_channel) return;
			
			log('channel was non-null');
			
			_channel.removeEventListener(flash.events.Event.SOUND_COMPLETE, onComplete);
			_paused = false;
			_position = 0;
			_channel = null;
		}
		
		private function onActivate(e:*):void
		{
			log('onActivate');
			// restart the sound where we left off
			resume();
		}

		private function onDeactivate(e:*):void
		{
			log('onDeactivate');
			pause();
		}
	}
}