module FMOD

  class ChannelControl

    ##
    # Emulates an Array-type container of a {ChannelControl}'s DSP chain.
    class DspChain

      include Enumerable

      ##
      # Creates a new instance of a {DspChain} for the specified
      # {ChannelControl}.
      #
      # @param channel [ChannelControl] The channel or channel group to create
      #   the collection wrapper for.
      def initialize(channel)
        FMOD.check_type(channel, ChannelControl)
        @channel = channel
      end

      ##
      # Retrieves the number of DSPs within the chain. This includes the
      # built-in {FMOD::Effects::Fader} DSP.
      # @return [Integer]
      def count
        buffer = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:ChannelGroup_GetNumDSPs, @channel, buffer)
        buffer.unpack1('l')
      end

      ##
      # @overload each(&block)
      #   If called with a block, passes each DSP in turn before returning self.
      #   @yield [dsp] Yields a DSP instance to the block.
      #   @yieldparam dsp [Dsp] The DSP instance.
      #   @return [self]
      # @overload each
      #   Returns an enumerator for the {DspChain} if no block is given.
      #   @return [Enumerator]
      def each
        return to_enum(:each) unless block_given?
        (0...count).each { |i| yield self[i] }
        self
      end

      ##
      # Element reference. Returns the element at index.
      # @param index [Integer] The index into the {DspChain} to retrieve.
      # @return [Dsp|nil] The DSP at the specified index, or +nil+ if index is
      #   out of range.
      def [](index)
        return nil unless index.between?(-2, count)
        dsp = "\0" * Fiddle::SIZEOF_INTPTR_T
        FMOD.invoke(:ChannelGroup_GetDSP, @channel, index, dsp)
        Dsp.from_handle(dsp)
      end

      ##
      # Element assignment. Sets the element at the specified index.
      # @param index [Integer] The index into the {DspChain} to set.
      # @param dsp [Dsp] A DSP instance.
      # @return [Dsp] The given DSP instance.
      def []=(index, dsp)
        FMOD.check_type(dsp, Dsp)
        FMOD.invoke(:ChannelGroup_AddDSP, @channel, index, dsp)
        dsp
      end

      ##
      # Appends or pushes the given object(s) on to the end of this {DspChain}. This
      # expression returns +self+, so several appends may be chained together.
      # @param dsp [Dsp] One or more DSP instance(s).
      # @return [self]
      def add(*dsp)
        dsp.each { |d| self[DspIndex::TAIL] = d }
        self
      end

      ##
      # Prepends objects to the front of +self+, moving other elements upwards.
      # @param dsp [Dsp] A DSP instance.
      # @return [self]
      def unshift(dsp)
        self[DspIndex::HEAD] = dsp
        self
      end

      ##
      # Removes the last element from +self+ and returns it, or +nil+ if the
      # {DspChain} is empty.
      # @return [Dsp|nil]
      def pop
        dsp = self[DspIndex::TAIL]
        remove(dsp)
        dsp
      end

      ##
      # Returns the first element of +self+ and removes it (shifting all other
      # elements down by one). Returns +nil+ if the array is empty.
      # @return [Dsp|nil]
      def shift
        dsp = self[DspIndex::HEAD]
        remove(dsp)
        dsp
      end

      ##
      # Deletes the specified DSP from this DSP chain. This does not release ot
      # dispose the DSP unit, only removes from this {DspChain}, as a DSP unit
      # can be shared.
      # @param dsp [Dsp] The DSP to remove.
      # @return [self]
      def remove(dsp)
        return unless dsp.is_a?(Dsp)
        FMOD.invoke(:ChannelGroup_RemoveDSP, @channel, dsp)
        self
      end

      ##
      # Returns the index of the specified DSP.
      # @param dsp [Dsp] The DSP to retrieve the index of.
      # @return [Integer] The index of the DSP.
      def index(dsp)
        FMOD.check_type(dsp, Dsp)
        buffer = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:ChannelGroup_GetDSPIndex, @channel, dsp, buffer)
        buffer.unpack1('l')
      end

      ##
      # Moves a DSP unit that exists in this {DspChain} to a new index.
      # @param dsp [Dsp] The DSP instance to move, must exist within this
      #   {DspChain}.
      # @param index [Integer] The new index to place the specified DSP.
      # @return [self]
      def move(dsp, index)
        FMOD.check_type(dsp, Dsp)
        FMOD.invoke(:ChannelGroup_SetDSPIndex, @channel, dsp, index)
        self
      end

      alias_method :size, :count
      alias_method :length, :count
      alias_method :delete, :remove
      alias_method :push, :add
      alias_method :<<, :add
    end
  end
end