require 'spec_helper'

describe CachingProxy::Resolvers::MultipleDestinationResolver do
  let(:route) { 'test-route-1' }
  let(:destination_map) do
    {
      route.to_sym => { host: 'http://example.com', port: 8080 }
    }
  end
  let(:destination_resolver) { Resolvers::MultipleDestinationResolver.new(destination_map) }

  describe '#get_destination_for_path' do
    let(:test_path) { "/#{route}/test/1/?v=true" }
    let(:result) { destination_resolver.get_destination_for_path(test_path) }

    context 'given a valid path' do
      it 'resolves the correct path' do
        expected = URI.parse('http://example.com:8080/test/1/?v=true')
        expect(result).to eq(expected)
      end
    end

    context 'given a path that is not configured' do
      let(:test_path) { '/not/a/configured_route' }

      it 'raises DestinationNotFound' do
        expect { result }.to raise_error(Resolvers::DestinationNotFound)
      end
    end
  end

  describe '#extract_path_info' do
    # not an exhaustive list, but this covers some basic url paths
    let(:test_paths) do
      {
        '/route'                      => ['route', nil],
        '/route/'                     => ['route', '/'],
        '/route/foo'                  => ['route', '/foo'],
        '/route/foo/'                 => ['route', '/foo/'],
        '/route/foo/23/'              => ['route', '/foo/23/'],
        '/route/foo/23/?id=1'         => ['route', '/foo/23/?id=1'],
        '/route/foo/23/?id=1&limit=1' => ['route', '/foo/23/?id=1&limit=1'],
        '/route-test/foo_bar/#hash'   => ['route-test', '/foo_bar/#hash'],
      }
    end

    it 'correctly extracts valid route and uri info' do
      test_paths.each do |request_path, expected|
        result = destination_resolver.extract_path_info(request_path)
        expect(result).to eq(expected)
      end
    end

    it 'raises InvalidDestinationPath when invalid' do
      expect { destination_resolver.extract_path_info('/') }.to raise_error(Resolvers::InvalidDestinationPath)
    end
  end
end
