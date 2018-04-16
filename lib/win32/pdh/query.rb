require 'win32/pdh'
require 'win32/pdh/counter'

module Win32
  module Pdh
    class Query
      def initialize(source=nil)
        source =
          if source.nil?
            FFI::Pointer::NULL
          else
            (source + "\0").encode('UTF-16LE')
          end
        handle_pointer = FFI::MemoryPointer.new(:pointer)
        status = PdhFFI.PdhOpenQueryW(source, FFI::Pointer::NULL, handle_pointer)
        raise PdhError, status unless status == Constants::ERROR_SUCCESS
        @handle = handle_pointer.read_pointer
      end
      
      def close
        # Only allow closing once
        unless @handle.nil?
          status = PdhFFI.PdhCloseQuery(@handle)
          raise PdhError, status unless status == Constants::ERROR_SUCCESS
          @handle = nil
        end
      end

      ##
      # Simple query opening function.  Uses the OpenQuery function and gets a
      # query, passes it into the block, and then closes it afterward.  If no
      # block is given, it just returns the query, and you are responsible for
      # closing it.  The GC will not close this for you, so you can easily leak
      # resources.  It's strongly recommended to use the block style if at all
      # possible to ensure resource cleanup.
      def self.open(source=nil)
        query = new source
        if block_given?
          begin
            return yield query
          ensure
            query.close
          end
        else
          query
        end
      end

      def real_time?
        PdhFFI.PdhIsRealTimeQuery(@handle) == :true
      end

      ##
      # Adds a counter to this query and return it as a Counter object.
      def add_counter(path)
        Counter.new(
          query: @handle,
          path: path,
        )
      end

      def collect_query_data
        status = PdhFFI.PdhCollectQueryData(@handle)
        raise PdhError, status unless status == Constants::ERROR_SUCCESS
      end
    end
  end
end
