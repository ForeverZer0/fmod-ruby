module FMOD
  class Geometry
    class Polygon

      include Enumerable

      private_class_method :new

      ##
      # The parent geometry object.
      # @return [Geometry]
      attr_reader :geometry

      ##
      # The index of the {Polygon} within its parent {Geometry} object.
      # @return [Integer]
      attr_reader :index

      ##
      # Creates a new instance of a Polygon object.
      # @note Polygon objects should not be created by the user, only through
      #   {Geometry.add_polygon}, as they are an abstract wrapper only, not
      #   backed by an actual object.
      # @param geometry [Geometry] The parent geometry object.
      # @param index [Integer] The index of the polygon within the geometry.
      # @api private
      def initialize(geometry, index)
        @geometry, @index = geometry, index
      end

      ##
      # @!attribute direct_occlusion
      # The occlusion value from 0.0 to 1.0 which affects volume or audible
      # frequencies.
      # * *Minimum:* 0.0 The polygon does not occlude volume or audible
      #   frequencies (sound will be fully audible)
      # * *Maximum:* 1.0 The polygon fully occludes (sound will be silent)
      #
      # @return [Float]

      def direct_occlusion
        occlusion = "\0" * Fiddle::SIZEOF_FLOAT
        FMOD.invoke(:Geometry_GetPolygonAttributes, @geometry, @index,
          occlusion, nil, nil)
        occlusion.unpack1('f')
      end

      def direct_occlusion=(occlusion)
        FMOD.invoke(:Geometry_SetPolygonAttributes, @geometry, @index,
          occlusion.clamp(0.0, 1.0), reverb_occlusion, double_sided.to_i)
      end

      ##
      # @!attribute reverb_occlusion
      # The occlusion value from 0.0 to 1.0 which affects the reverb mix.
      # * *Minimum:* 0.0 The polygon does not occlude reverb (reverb
      #   reflections still travel through this polygon)
      # * *Maximum:* 1.0 The polygon fully occludes reverb (reverb
      #   reflections will be silent through this polygon)
      #
      # @return [Float]

      def reverb_occlusion
        occlusion = "\0" * Fiddle::SIZEOF_FLOAT
        FMOD.invoke(:Geometry_GetPolygonAttributes, @geometry, @index,
          nil, occlusion, nil)
        occlusion.unpack1('f')
      end

      def reverb_occlusion=(occlusion)
        FMOD.invoke(:Geometry_SetPolygonAttributes, @geometry, @index,
          direct_occlusion, occlusion.clamp(0.0, 1.0), double_sided.to_i)
      end

      ##
      # @!attribute double_sided
      # The description of polygon if it is double sided or single sided.
      # * *true:* The polygon is double sided
      # * *false:* The polygon is single sided, and the winding of the polygon
      #   (which determines the polygon's normal) determines which side of the
      #   polygon will cause occlusion.
      #
      # @return [Boolean]

      def double_sided
        double = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:Geometry_GetPolygonAttributes, @geometry, @index,
          nil, nil, double)
        double.unpack1('l') != 0
      end

      def double_sided=(double_sided)
        FMOD.invoke(:Geometry_SetPolygonAttributes, @geometry, @index,
          direct_occlusion, reverb_occlusion, double_sided.to_i)
      end

      ##
      # Retrieves the number of vertices within the polygon.
      # @return [Integer]
      def vertex_count
        count = "\0" * Fiddle::SIZEOF_INT
        FMOD.invoke(:Geometry_GetPolygonNumVertices, @geometry, @index, count)
        count.unpack1('l')
      end

      alias_method :size, :vertex_count

      ##
      # Retrieves the vertex of the polygon at the specified index.
      # @param index [Integer] The index of the vertex to retrieve.
      # @return [Vector]
      def [](index)
        return nil unless index.between?(0, vertex_count - 1)
        vertex = Vector.zero
        FMOD.invoke(:Geometry_GetPolygonVertex, @geometry, @index, index, vertex)
        vertex
      end

      ##
      # Sets the vertex of the polygon at the specified index.
      # @param index [Integer] The index of the vertex to set.
      # @param vertex [Vector] The vertex to set.
      # @return [Vector] The vertex.
      def []=(index, vertex)
        unless index.between?(0, vertex_count - 1)
          message = "Index #{index} outside of bounds: 0...#{vertex.count}"
          raise IndexError, message
        end
        FMOD.check_type(vertex, Vector)
        FMOD.invoke(:Geometry_SetPolygonVertex, @geometry, @index, index, vertex)
      end

      ##
      # @overload each
      #   When called with a block, yields each vertex in turn before returning
      #   self.
      #   @yield [vertex] Yields a vertex to the block.
      #   @yieldparam vertex [Vector] The enumerated vertex.
      #   @return [self]
      # @overload each
      #   Returns an Enumerator for the polygon.
      #   @return [Enumerator]
      def each
        return to_enum(:each) unless block_given?
        (0...vertex_count).each { |i| yield self[i] }
        self
      end

      ##
      # Retrieves an array of the vertices within the polygon.
      # @return [Array<Vector>]
      def vertices
        (0...vertex_count).map { |i| self[i] }
      end
    end
  end
end