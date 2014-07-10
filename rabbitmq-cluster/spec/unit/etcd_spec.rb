require 'spec_helper'

describe RabbitMQ::Cluster::Etcd do
  let(:etcd_client) { double }
  subject { described_class.new(etcd_client) }

  describe '#nodes' do
    it 'returns the list of nodes registed in etcd' do
      allow(etcd_client).to receive(:get).with('/rabbitmq/nodes').and_return(
        {
          "/rabbitmq/nodes/rabbit@rabbit1" => "rabbit@rabbit1",
          "/rabbitmq/nodes/rabbit@rabbit2" => "rabbit@rabbit2"
        }
      )
      expect(subject.nodes).to eq ["rabbit@rabbit1", "rabbit@rabbit2"]
    end

    it 'returns an empty array if there are no nodes registered' do
      allow(etcd_client).to receive(:get).with('/rabbitmq/nodes')
      expect(subject.nodes).to eq []
    end
  end

  describe '#register' do
    let(:nodename) { 'rabbit@mynode' }

    context 'the node is not yet registered' do

      before do
        allow(etcd_client).to receive(:exists?)
                                .with("/rabbitmq/nodes/#{nodename}")
      end

      it 'sets the key in etcd' do
        expect(etcd_client).to receive(:set)
                                 .with(
                                   "/rabbitmq/nodes/#{nodename}",
                                   nodename
                                 )
        subject.register(nodename)
      end
    end

    context 'the node is allready registered' do
      before do
        allow(etcd_client).to receive(:exists?)
                               .with("/rabbitmq/nodes/#{nodename}")
                                .and_return true
      end

      it 'does nothing' do
        expect(etcd_client).to_not receive(:set)
        subject.register(nodename)
      end
    end
  end

  describe '#erlang_cookie' do
    let(:erlang_cookie) { 'afbdgCVB23423bh324h' }
    before do
      allow(etcd_client).to receive(:get)
                              .with('/rabbitmq/erlang_cookie')
                              .and_return(erlang_cookie)
    end

    it 'has a getter' do
      expect(subject.erlang_cookie).to eq erlang_cookie
    end

    it 'has a setter' do
      expect(etcd_client).to receive(:set)
                               .with(
                                 '/rabbitmq/erlang_cookie',
                                 erlang_cookie
                               )
      subject.erlang_cookie = erlang_cookie
    end
  end

  describe '#aquire_lock' do
    let(:thingy) { double(run: nil) }
    before do
      allow(etcd_client).to receive(:update).with('/rabbitmq/lock', false, true).and_return(true)
      allow(etcd_client).to receive(:update).with('/rabbitmq/lock', true, false).and_return(true)
    end

    describe 'when we can get the lock' do
      it 'runs the code' do
        expect(etcd_client).to receive(:update).with('/rabbitmq/lock', true, false).and_return(true)
        expect(thingy).to receive(:run)

        subject.aquire_lock { thingy.run }
      end

      it 'gives the lock back when its done' do
        expect(etcd_client).to receive(:update).with('/rabbitmq/lock', false, true).and_return(true)

        subject.aquire_lock { thingy.run }
      end

      it 'gets angry if something odd happens' do
        allow(etcd_client).to receive(:update).with('/rabbitmq/lock', false, true).and_return(false)

        expect { subject.aquire_lock { thingy.run } }.to raise_error
      end
    end

    describe "when we can't get the lock" do
      it 'retries till the lock can be aquired' do
        expect(etcd_client).to receive(:update)
                                 .with('/rabbitmq/lock', true, false)
                                 .at_least(3).times
                                 .and_return(false, false, true)
        expect(thingy).to receive(:run)

        subject.aquire_lock { thingy.run }
      end
    end
  end
end