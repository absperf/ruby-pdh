require 'win32/pdh'

module Win32
  module Pdh
    module Query
      def initialize(source=nil)
        source =
          if source.nil?
            FFI::Pointer::NULL
          else
            (source + "\0").encode('UTF-16LE')
          end
        handle_pointer = FFI::MemoryPointer.new(:pointer)
        PdhFFI.PdhOpenQueryW(source, FFI::Pointer::NULL, handle_pointer)
        @handle = handle_pointer.read_pointer
      end
      
      def close
        # Only allow closing once
        PdhFFI.PdhCloseQuery(@handle) unless @handle.nil?
        @handle = nil
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
            yield query
          ensure
            query.close
          end
        else
          query
        end
      end

      private_class_method :new
    end
  end
end
