package kheftel.util
{
	import flash.desktop.NativeApplication;
	import flash.events.Event;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.media.SoundTransform;
	import flash.system.Capabilities;

	/**
	 * Auto-pauses self on Android when app loses focus.
	 */
	public class PauseableSound
	{
		private var _sound:Sound;
		private var _channel:SoundChannel;
		private var _position:Number;
		private var _transform:SoundTransform;
		private var _paused:Boolean;
		private var _loop:Boolean;
		
		public function PauseableSound(s:Sound)
		{
			if(s == null) throw new ArgumentError('sound cannot be null');
			
			_sound = s;
			_position = 0;
			_transform = new SoundTransform();
			_paused = false;
			_loop = false;
			
			// auto-pause and resume the sound on Android so sounds don't play in the background after app loses focus
			if(Capabilities.manufacturer.indexOf("Android") != -1)
			{
				NativeApplication.nativeApplication.addEventListener(flash.events.Event.ACTIVATE, onActivate, false, 0, true);
				NativeApplication.nativeApplication.addEventListener(flash.events.Event.DEACTIVATE, onDeactivate, false, 0, true);
			}
		}
		
		public function get paused():Boolean
		{
			return _paused;
		}

		/**
		 * must be called when you're done with the sound to dispose resources
		 */
		public function dispose():void
		{
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
			if(_channel)
			{
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
			
			_channel = _sound.play(_position, _loop ? int.MAX_VALUE : 0, _transform);
			_channel.addEventListener(flash.events.Event.SOUND_COMPLETE, onComplete, false, 0, true);
		}
		
		/**
		 * stops sound, resets to beginning
		 */
		public function stop():void
		{
			if(_channel)
			{
				_channel.stop();
				_position = 0;
				_channel = null;
			}
		}
		
		public function play(volume:Number = 1, loop:Boolean = false, pan:Number = 0, startTime:Number = 0):void
		{
			// only allow one instance of the sound to play at a time
			if(_channel)
			{
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
			if(!_channel) return;
			
			_channel.removeEventListener(flash.events.Event.SOUND_COMPLETE, onComplete);
			_paused = false;
			_position = 0;
			_channel = null;
		}
		
		protected function onActivate(e:*):void
		{
			if(_paused)
			{
				// restart the sound where we left off
				resume();
			}
		}

		protected function onDeactivate(e:*):void
		{
			if(!_paused)
				pause();
		}
	}
}