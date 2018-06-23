module FMOD

  class Sound

    class TagCollection

      include Enumerable

      private_class_method :new

      def initialize(sound)
        @sound = sound
      end

      def each
        return to_enum(:each) unless block_given?
        (0...count).each { |i| yield self[i] }
        self
      end

      def count
        buffer = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:Sound_GetNumTags, @sound, buffer, nil)
        buffer.unpack1('l')
      end

      alias_method :size, :count

      def updated_count
        buffer = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:Sound_GetNumTags, @sound, nil, buffer)
        buffer.unpack1('l')
      end

      def [](index)
        tag = FMOD::Structs::Tag.new
        if index.is_a?(Integer)
          return nil unless index.between?(0, count - 1)
          FMOD.invoke(:Sound_GetTag, @sound, nil, index, tag)
        elsif tag.is_a?(String)
          FMOD.invoke(:Sound_GetTag, @sound, index, 0, tag)
        end
        tag
      end
    end
  end
end