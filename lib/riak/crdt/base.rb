module Riak
  module Crdt
    class Base
      def initialize(bucket, key, bucket_type, options={})
        @bucket = bucket
        @key = key
        @bucket_type = bucket_type
        @options = options
      end

      def reload
        response = client.backend do |be|
          be.fetch_crdt @bucket, @key, @bucket_type, @options
        end
        @result = response.value
      end

      def backend_class
        backend.class
      end
      
      private
      def result
        return @result if @result
        reload
        @result
      end
      
      def client
        @bucket.client
      end

      def backend
        client.backend{|be| be}
      end

      def send_operation(operation, options={})
        backend.update_crdt @bucket, @key, @bucket_type, operation, options
      end
    end
  end
end
