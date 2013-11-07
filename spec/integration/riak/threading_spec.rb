require 'spec_helper'

describe "Multithreaded client", :test_client => true do
  class Synchronizer
    def initialize(n)
      @mutex = Mutex.new
      @n = n
      @waiting = Set.new
    end

    def sync
      stop = false
      @mutex.synchronize do
        @waiting << Thread.current

        if @waiting.size >= @n
          # All threads are waiting.
          @waiting.each do |t|
            t.run
          end
        else
          stop = true
        end
      end

      if stop
        Thread.stop
      end
    end
  end

  def threads(n, opts = {})
    if opts[:synchronize]
      s1 = Synchronizer.new n
      s2 = Synchronizer.new n
    end

    threads = (0...n).map do |i|
      Thread.new do
        if opts[:synchronize]
          s1.sync
        end

        yield i

        if opts[:synchronize]
          s2.sync
        end
      end
    end

    threads.each do |t|
      t.join
    end
  end

  [
   {:protobuffs_backend => :Beefcake}
  ].each do |opts|
    describe opts.inspect do
      before do
        @bucket = random_bucket 'threading'
      end

      it 'should get in parallel' do
        data = "the gun is good"
        ro = @bucket.new('test')
        ro.content_type = "application/json"
        ro.data = [data]
        ro.store

        threads 10, :synchronize => true do
          x = @bucket['test']
          x.content_type.should == "application/json"
          x.data.should == [data]
        end
      end

      it 'should put in parallel' do
        data = "the tabernacle is indestructible and everlasting"

        n = 10
        threads n, :synchronize => true do |i|
          x = @bucket.new("test-#{i}")
          x.content_type = "application/json"
          x.data = ["#{data}-#{i}"]
          x.store
        end

        (0...n).each do |i|
          read = @bucket["test-#{i}"]
          read.content_type.should == "application/json"
          read.data.should == ["#{data}-#{i}"]
        end
      end

      # This is a 1.0+ spec because putting with the same client ID
      # will not create siblings on 0.14 in the same way. This will
      # also likely fail for nodes with vnode_vclocks = false.
      it 'should put conflicts in parallel' do
        @bucket.allow_mult = true
        @bucket.allow_mult.should == true

        init = @bucket.new('test')
        init.content_type = "application/json"
        init.data = ''
        init.store

        # Create conflicting writes
        n = 10
        s = Synchronizer.new n
        threads n, :synchronize => true do |i|
          x = @bucket["test"]
          s.sync
          x.data = [i]
          x.store
        end

        read = @bucket["test"]
        read.conflict?.should == true
        read.siblings.map do |sibling|
          sibling.data.first
        end.to_set.should == (0...n).to_set
      end

      it 'should list-keys and get in parallel', :slow => true do
        count = 100
        threads = 2

        # Create items
        count.times do |i|
          o = @bucket.new("#{i}")
          o.content_type = 'application/json'
          o.data = [i]
          o.store
        end

        threads(threads) do
          set = Set.new
          @bucket.keys do |stream|
            stream.each do |key|
              set.merge @bucket[key].data
            end
          end
          set.should == (0...count).to_set
        end
      end
    end
  end
end
