require 'spec_helper'
require 'riak'

describe "CRDTs", integration: true, test_client: true do
  let(:bucket) { random_bucket }
  describe 'configuration' do
    it "should allow default bucket-types to be configured for each data type"
    it "should allow override bucket-types for instances"
  end
  describe 'counters' do
    subject { Riak::Crdt::Counter.new bucket, random_key }
    it 'should allow straightforward counter ops' do
      start = subject.value
      subject.increment
      expect(subject.value).to eq(start + 1)
      subject.increment
      expect(subject.value).to eq(start + 2)
      subject.increment -1
      expect(subject.value).to eq(start + 1)
      subject.decrement
      expect(subject.value).to eq(start)
    end
    
    it 'should allow batched counter ops' do
      start = subject.value
      subject.batch do |s|
        s.increment
        s.increment 2
        s.increment
        s.increment
      end
      expect(subject.value).to eq(start + 5)
    end
  end
  describe 'sets' do

    subject { Riak::Crdt::Set.new bucket, random_key }
    
    it 'should allow straightforward set ops' do
      start = subject.members
      addition = random_key

      subject.add addition
      expect(subject.include? addition).to be
      expect(subject.members).to include(addition)

      subject.remove addition
      expect(subject.include? addition).to_not be
      expect(subject.members).to_not include(addition)
      expect(subject.members).to eq(start)
    end
    
    it 'should allow batched set ops'
  end
  describe 'maps' do
    subject { Riak::Crdt::Map.new bucket, random_key }
    
    it 'should allow straightforward map ops' do
      subject.registers['first'] = 'hello'
      expect(subject.registers['first']).to eq('hello')

      subject.sets['arnold'].add 'commando'
      subject.sets['arnold'].add 'terminator'
      expect(subject.sets['arnold'].members).to include('commando')
      subject.sets['arnold'].remove 'commando'
      expect(subject.sets['arnold'].members).to_not include('commando')
      expect(subject.sets['arnold'].members).to include('terminator')

      subject.maps['first'].registers['second'] = 'good evening'
      subject.maps['first'].maps['third'].counters['fourth'].increment

      expect(subject.maps['first'].registers['second']).to eq('good evening')
      expect(subject.maps['first'].maps['third'].counters['fourth'].value).to eq(1)
    end
    it 'should allow batched map ops'
    
    describe 'containing a map' do
      it 'should bubble straightforward map ops up'
      it 'should bubble inner-map batches up'
      it 'should include inner-map ops in the outer-map batch'
    end

    describe 'containing a register' do
      it 'should bubble straightforward register ops up'
      # registers don't have batch ops
    end

    describe 'containing a flag' do
      it 'should bubble straightforward flag ops up'
      # flags don't have batch ops
    end
  end
end
