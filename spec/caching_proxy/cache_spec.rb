require 'spec_helper'

describe CachingProxy::Cache do

  let(:ttl_seconds) { 30 }
  let(:max_size_bytes) { 1024 }
  let(:max_size_elements) { 5 }
  let(:cache_options) do
    {
      ttl: ttl_seconds * 1000,
      max_size_bytes: max_size_bytes,
      max_size_elements: max_size_elements
    }
  end
  let(:cache) { CachingProxy::Cache.new(cache_options) }
  let(:test_key) { 'cache-key-1' }
  let(:test_value) { 'cache-entry-1' }
  let(:cache_result) { cache.get(test_key) }
  let(:time_now) { Time.now }

  describe '#get' do
    before do
      allow(cache).to receive(:evict).and_call_original
      allow(cache).to receive(:touch).and_call_original
    end

    context 'when there is no entry for the given key' do
      it 'does not evict anything and returns nil' do
        expect(cache).not_to receive(:evict)
        expect(cache_result).to be_nil
      end
    end

    context 'when the requested entry has expired' do
      before do
        Timecop.freeze(time_now - ttl_seconds - 5) { cache.put(test_key, test_value) }
      end

      it 'evicts the entry and returns nil' do
        expect(cache).to receive(:evict).with(test_key)
        expect(cache_result).to be_nil
      end
    end

    context 'when the entry is present and valid' do
      before do
        cache.put(test_key, test_value)
      end

      it 'refreshes the key and returns the result' do
        expect(cache).to receive(:touch).with(test_key)
        expect(cache).not_to receive(:evict)
        expect(cache_result).to eq(test_value)
      end
    end
  end

  describe '#put' do
    before do
      allow(cache).to receive(:evict).and_call_original
    end

    context 'when the cache is empty' do
      it 'does not evict any entry and caches the value' do
        expect(cache).not_to receive(:evict)

        cache.put(test_key, test_value)
        expect(cache_result).to eq(test_value)
      end
    end

    context 'when the key already exists in the cache' do
      before do
        cache.put(test_key, test_value)
      end

      it 'evicts the existing entry and caches the value' do
        expect(cache).to receive(:evict).with(test_key)

        cache.put(test_key, test_value)
        expect(cache_result).to eq(test_value)
      end
    end

    context 'when there is an expired entry' do
      let(:expired_key) { 'expired-key' }

      before do
        Timecop.freeze(time_now - ttl_seconds - 5) { cache.put(expired_key, test_value) }
      end

      it 'evicts the expired entry and caches the new svalue' do
        expect(cache).to receive(:evict).with(expired_key)
        expect(cache).not_to receive(:evict).with(test_key)

        cache.put(test_key, test_value)
        expect(cache_result).to eq(test_value)
      end
    end

    context 'when the cache entry exceeds the maximum byte size' do
      let(:test_value) { '1' * max_size_bytes }

      it 'does not evict any entry and caches the value' do
        expect(cache).not_to receive(:evict)

        expect(cache.put(test_key, test_value)).to be_nil
        expect(cache_result).to be_nil
      end
    end

    context 'when an entry needs to be evicted due to size constraints' do
      # simulate this by adding a couple of entries which bring us close to max size
      let(:existing_key_1) { 'existing-key-1' }
      let(:existing_key_2) { 'existing-key-2' }
      let(:large_value) { '1' * (max_size_bytes / 2 - 50) }
      let(:test_value) { '1' * 100 }

      before do
        cache.put(existing_key_1, large_value)
        cache.put(existing_key_2, large_value)
      end

      it 'evicts the first existing key and caches the new value' do
        expect(cache).to receive(:evict).with(existing_key_1)
        expect(cache).not_to receive(:evict).with(existing_key_2)
        expect(cache).not_to receive(:evict).with(test_key)

        cache.put(test_key, test_value)
        expect(cache_result).to eq(test_value)
      end
    end

    context 'when an entry needs to be evicted due to the number of elements' do
      let(:existing_keys) { 1.upto(max_size_elements).map(&:to_s) }

      before do
        existing_keys.each { |k| cache.put(k, 'existing-value') }
      end

      it 'evicts the first existing key and caches the new value' do
        expect(cache).to receive(:evict).with(existing_keys.first)
        existing_keys[1..-1].each { |k| expect(cache).not_to receive(:evict).with(k) }
        expect(cache).not_to receive(:evict).with(test_key)

        cache.put(test_key, test_value)
        expect(cache_result).to eq(test_value)
      end
    end
  end
end
