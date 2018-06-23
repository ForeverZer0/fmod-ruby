
require_relative 'handle'

module FMOD
  class System < Handle

    CpuUsage = Struct.new(:dsp, :stream, :geometry, :update, :total)

    RamUsage = Struct.new(:current, :max, :total)

    FileUsage = Struct.new(:sample, :stream, :other)

    # @!group Object Creation

    def self.create(**options)
      max = [options[:max_channels] || 32, 4093].min
      flags = options[:flags] || InitFlags::NORMAL
      driver = options[:driver_data] || FMOD::NULL
      FMOD.invoke(:System_Create, address = "\0" * SIZEOF_INTPTR_T)
      sys = new(address)
      FMOD.invoke(:System_Init, sys, max, flags, driver)
      sys
    end

    def create_sound(source, **options)
      mode = options[:mode] || Mode::DEFAULT
      extra = options[:extra] || FMOD::NULL
      sound = int_ptr
      FMOD.invoke(:System_CreateSound, self, source, mode, extra, sound)
      Sound.new(sound)
    end

    def create_stream(source, **options)
      mode = options[:mode] || Mode::DEFAULT
      extra = options[:extra] || FMOD::NULL
      sound = int_ptr
      FMOD.invoke(:System_CreateSound, self, source, mode, extra, sound)
      Sound.new(sound)
    end

    def create_dsp(type)
      unless FMOD.check_type(type, Integer, false)
        unless FMOD.check_type(type, Class) && type < Dsp
          raise TypeError, "#{type} must either be or inherit from #{Dsp}."
        end
      end
      if type.is_a?(Integer)
        klass = Dsp.type_map(type)
      else type.is_a?(Class)
      klass = type
      type = Dsp.type_map(type)
      end
      dsp = int_ptr
      FMOD.invoke(:System_CreateDSPByType, self, type, dsp)
      klass.new(dsp)
    end

    def create_sound_group(name)
      utf8 = name.encode('UTF-8')
      group = int_ptr
      FMOD.invoke(:System_CreateSoundGroup, self, utf8, group)
      SoundGroup.new(group)
    end

    def create_geometry(max_polygons, max_vertices)
      geometry = int_ptr
      FMOD.invoke(:System_CreateGeometry, self, max_polygons, max_vertices, geometry)
      Geometry.new(geometry)
    end

    def create_reverb
      reverb = int_ptr
      FMOD.invoke(:System_CreateReverb3D, self, reverb)
      Reverb3D.new(reverb)
    end

    ##
    # Creates a {Geometry} object that was previously serialized with
    # {Geometry.save}.
    # @param source [String] Either a filename where object is saved, or a
    #   binary block of serialized data.
    # @param filename [Boolean] +true+ if source is a filename to be loaded,
    #   otherwise +false+ and source will be handled as binary data.
    # @return [Geometry]
    # @see Geometry.save
    def load_geometry(source, filename = true)
      source = IO.open(source, 'rb') { |io| io.read } if filename
      size = source.bytesize
      FMOD.invoke(:System_LoadGeometry, self, source, size, geometry = int_ptr)
      Geometry.new(geometry)
    end

    # @!endgroup

    def update
      FMOD.invoke(:System_Update, self)
    end

    def close
      FMOD.invoke(:System_Close, self)
    end



    ##
    # Returns the current version of FMOD being used.
    # @return [String]
    def version
      FMOD.invoke(:System_GetVersion, self, version = "\0" * SIZEOF_INT)
      version = version.unpack1('L').to_s(16).rjust(8, '0')
      major = version[0, 4].to_i
      minor = version[4, 2].to_i
      build = version[6, 2].to_i
      "#{major}.#{minor}.#{build}"
    end

    ##
    # Plays a sound object on a particular channel and {ChannelGroup}.
    #
    # When a sound is played, it will use the sound's default frequency and
    # priority.
    #
    # A sound defined as FMOD_3D will by default play at the position of the
    # listener.
    #
    # Channels are reference counted. If a channel is stolen by the FMOD
    # priority system, then the handle to the stolen voice becomes invalid, and
    # Channel based commands will not affect the new sound playing in its place.
    # If all channels are currently full playing a sound, FMOD will steal a
    # channel with the lowest priority sound. If more channels are playing than
    # are currently available on the sound-card/sound device or software mixer,
    # then FMOD will "virtualize" the channel. This type of channel is not
    # heard, but it is updated as if it was playing. When its priority becomes
    # high enough or another sound stops that was using a real hardware/software
    # channel, it will start playing from where it should be. This technique
    # saves CPU time (thousands of sounds can be played at once without actually
    # being mixed or taking up resources), and also removes the need for the
    # user to manage voices themselves. An example of virtual channel usage is a
    # dungeon with 100 torches burning, all with a looping crackling sound, but
    # with a sound-card that only supports 32 hardware voices. If the 3D
    # positions and priorities for each torch are set correctly, FMOD will play
    # all 100 sounds without any 'out of channels' errors, and swap the real
    # voices in and out according to which torches are closest in 3D space.
    # Priority for virtual channels can be changed in the sound's defaults, or
    # at runtime with {Channel.priority}.
    #
    # @param sound [Sound] The sound to play.
    # @param group [ChannelGroup] The {ChannelGroup} become a member of. This is
    #   more efficient than using {Channel.group}, as it does it during the
    #   channel setup, rather than connecting to the master channel group, then
    #   later disconnecting and connecting to the new {ChannelGroup} when
    #   specified. Specify +nil+ to ignore (use master {ChannelGroup}).
    # @param paused [Boolean] flag to specify whether to start the channel
    #   paused or not. Starting a channel paused allows the user to alter its
    #   attributes without it being audible, and un-pausing with
    #   ChannelControl.resume actually starts the sound.
    # @return [Channel] the newly playing channel.
    def play_sound(sound, group = nil, paused = false)
      FMOD.check_type(sound, Sound)
      channel = int_ptr
      paused = paused.to_i
      FMOD.invoke(:System_PlaySound, self, sound, group, paused, channel)
      Channel.new(channel)
    end

    def [](index)
      reverb = int_ptr
      FMOD.invoke(:System_GetReverbProperties, self, index, reverb)
      Reverb.new(reverb.unpack1('J'))
    end

    def []=(index, reverb)
      FMOD.check_type(reverb, Reverb)
      FMOD.invoke(:System_SetReverbProperties, self, index, reverb)
    end

    def mixer_suspend
      FMOD.invoke(:System_MixerSuspend, self)
      if block_given?
        yield
        FMOD.invoke(:System_MixerResume, self)
      end
    end

    def mixer_resume
      FMOD.invoke(:System_MixerResume, self)
    end

    ##
    # Mutual exclusion function to lock the FMOD DSP engine (which runs
    # asynchronously in another thread), so that it will not execute. If the
    # FMOD DSP engine is already executing, this function will block until it
    # has completed.
    #
    # The function may be used to synchronize DSP network operations carried out
    # by the user.
    #
    # An example of using this function may be for when the user wants to
    # construct a DSP sub-network, without the DSP engine executing in the
    # background while the sub-network is still under construction.
    #
    # Once the user no longer needs the DSP engine locked, it must be unlocked
    # with {#unlock_dsp}.
    #
    # Note that the DSP engine should not be locked for a significant amount of
    # time, otherwise inconsistency in the audio output may result. (audio
    # skipping/stuttering).
    #
    # @overload lock_dsp
    #   Locks the DSP engine, must unlock with {#unlock_dsp}.
    # @overload lock_dsp
    #   @yield Locks the DSP engine, and unlocks it when the block exits.
    # @return [void]
    def lock_dsp
      FMOD.invoke(:System_LockDSP, self)
      if block_given?
        yield
        FMOD.invoke(:System_UnlockDSP, self)
      end
    end

    ##
    # Mutual exclusion function to unlock the FMOD DSP engine (which runs
    # asynchronously in another thread) and let it continue executing.
    #
    # @note The DSP engine must be locked with {#lock_dsp} before this function
    # is called.
    # @return [void]
    def unlock_dsp
      FMOD.invoke(:System_UnlockDSP, self)
    end

    # @!group System Resources

    ##
    # Retrieves in percent of CPU time - the amount of CPU usage that FMOD is
    # taking for streaming/mixing and {#update} combined.
    #
    # @return [CpuUsage] the current CPU resource usage at the time of the call.
    def cpu_usage
      args = ["\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT,
        "\0" * SIZEOF_FLOAT, "\0" * SIZEOF_FLOAT]
      FMOD.invoke(:System_GetCPUUsage, self, *args)
      CpuUsage.new(*args.map { |arg| arg.unpack1('f') })
    end

    ##
    # Retrieves the amount of dedicated sound ram available if the platform
    # supports it.
    #
    # Most platforms use main RAM to store audio data, so this function usually
    # isn't necessary.
    #
    # @return [RamUsage] the current RAM resource usage at the time of the call.
    def ram_usage
      args = ["\0" * SIZEOF_INT, "\0" * SIZEOF_INT, "\0" * SIZEOF_INT]
      FMOD.invoke(:System_GetSoundRAM, self, *args)
      RamUsage.new(*args.map { |arg| arg.unpack1('l') })
    end

    ##
    # Retrieves information about file reads by FMOD.
    #
    # The values returned are running totals that never reset.
    #
    # @return [FileUsage] the current total of file read resources used by FMOD
    #   at the time of the call.
    def file_usage
      args = ["\0" * SIZEOF_LONG_LONG, "\0" * SIZEOF_LONG_LONG,
        "\0" * SIZEOF_LONG_LONG]
      FMOD.invoke(:System_GetFileUsage, self, *args)
      FileUsage.new(*args.map { |arg| arg.unpack1('q') })
    end

    # @!endgroup

    def each_dsp
      return to_enum(:each_dsp) unless block_given?
      FMOD::DspType.constants(false).each do |const|
        type = DspType.const_get(const)
        yield create_dsp(type) rescue next
      end
      self
    end
  end
end