require 'spec_helper'

describe CachingProxy::Server do
  let(:cache) { double(Cache) }
  let(:destination_resolver) { double(Resolvers::SingleDestinationResolver) }
  let(:port) { 9999 }
  let(:server) { Server.new(port, cache, destination_resolver) }
  let(:test_path) { '/test/path' }
  let(:request) { double(WEBrick::HTTPRequest, unparsed_uri: test_path) }
  let(:response) { WEBrick::HTTPResponse.new(WEBrick::Config::HTTP) }

  before do
    # Don't actually instantiate an http server
    allow(WEBrick::HTTPServer).to receive(:new).and_return(double(WEBrick::HTTPServer, mount_proc: nil))
    # Ensure we have a clean object
    response.status = 0
    response.body = nil
  end

  describe '#do_request' do
    context 'given a non-GET request' do
      before do
        allow(request).to receive(:request_method).and_return('POST')
      end

      it 'returns a 405 and does not process the request' do
        expect(server).not_to receive(:do_get)
        server.do_request(request, response)
        expect(response.status).to eq(405)
      end
    end

    context 'given a GET request' do
      before do
        allow(request).to receive(:request_method).and_return('GET')
      end

      it 'returns a 405 and does not process the request' do
        expect(server).to receive(:do_get).with(request, response)
        server.do_request(request, response)
      end
    end
  end

  describe '#do_get' do
    let(:status) { 200 }
    let(:body) { 'test-body' }
    let(:response_data) { [status, body] }
    let(:destination) { 'test-destination' }

    context 'when the page is cached' do
      before do
        allow(cache).to receive(:get).with(test_path).and_return(response_data)
      end

      it 'sends back the cached response' do
        expect(cache).not_to receive(:put)
        server.do_get(request, response)
        expect(response.status).to eq(status)
        expect(response.body).to eq(body)
      end
    end

    context 'when the page is not cached' do
      before do
        allow(cache).to receive(:get).and_return(nil)
        allow(destination_resolver).to receive(:get_destination_for_path).with(test_path).and_return(destination)
        allow(server).to receive(:forward_request).and_return(response_data)
      end

      it 'caches the page and sends back the response' do
        expect(server).to receive(:forward_request).with(destination)
        expect(cache).to receive(:put).with(test_path, response_data)
        server.do_get(request, response)
        expect(response.status).to eq(status)
        expect(response.body).to eq(body)
      end
    end
  end
end
