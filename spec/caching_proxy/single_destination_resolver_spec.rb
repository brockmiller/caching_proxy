require 'spec_helper'

describe CachingProxy do
  describe '#get_destination_for_path' do
    let(:host) { 'http://example.com' }
    let(:port) { 8080 }
    let(:test_path) { "/test/1/?v=true" }
    let(:destination_resolver) { Resolvers::SingleDestinationResolver.new(host, port) }
    let(:result) { destination_resolver.get_destination_for_path(test_path) }

    it 'resolves the correct path' do
      expected = URI.parse('http://example.com:8080/test/1/?v=true')
      expect(result).to eq(expected)
    end
  end
end
