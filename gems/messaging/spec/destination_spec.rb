
require 'torquebox/messaging/queue'
require 'torquebox/messaging/topic'
require 'torquebox/service_registry'

java_import org.mockito.ArgumentCaptor
java_import org.mockito.Matchers
java_import org.mockito.Mockito
java_import org.hornetq.jms.server.impl.JMSServerManagerImpl

describe TorqueBox::Messaging::Destination do

  it "should return its name for to_s" do
    queue = TorqueBox::Messaging::Queue.new("/queues/foo")
    queue.name.should == "/queues/foo"
    topic = TorqueBox::Messaging::Topic.new("/topics/bar")
    topic.name.should == "/topics/bar"
  end

  it "should fall back to internal connection factory" do
    factory = Object.new
    TorqueBox::Registry.merge!("connection-factory" => factory)
    queue = TorqueBox::Messaging::Queue.new("/queues/foo")
    queue.connection_factory.internal_connection_factory.should == factory
  end

  it "should initialize with connection factory if given" do
    factory = Object.new
    queue = TorqueBox::Messaging::Queue.new("/queues/foo", factory)
    queue.connection_factory.internal_connection_factory.should == factory
    queue.connect_options.should be_empty
  end

  it "should default to no connect options" do
    queue = TorqueBox::Messaging::Queue.new("/queues/foo")
    queue.connect_options.should be_empty
  end

  it "should initialize with connect options if given" do
    queue = TorqueBox::Messaging::Queue.new("/queues/foo", :naming_host => "bart")
    queue.connect_options[:naming_host].should == "bart"
  end

  it "should start and stop a queue" do
    server = Mockito.mock(JMSServerManagerImpl.java_class)
    TorqueBox::ServiceRegistry.stub!(:lookup).with("jboss.messaging.default.jms.manager").and_yield(server)

    queue = TorqueBox::Messaging::Queue.start( "my_queue" )
    queue.name.should == "my_queue"
    queue.stop

    Mockito.verify(server).createQueue(Matchers.anyBoolean,
                                       Matchers.eq("my_queue"),
                                       Matchers.anyString,
                                       Matchers.anyBoolean)
    Mockito.verify(server).destroyQueue("my_queue")
  end

  it "should start and stop a topic" do
    server = Mockito.mock(JMSServerManagerImpl.java_class)
    TorqueBox::ServiceRegistry.stub!(:lookup).with("jboss.messaging.default.jms.manager").and_yield(server)

    topic = TorqueBox::Messaging::Topic.start( "my_topic" )
    topic.name.should == "my_topic"
    topic.stop

    Mockito.verify(server).createTopic(Matchers.anyBoolean,
                                       Matchers.eq("my_topic"))

    Mockito.verify(server).destroyTopic("my_topic")
  end

  describe "publish" do
    before(:each) do
      @session = mock('session')
      @session.stub(:transacted?).and_return(false)
      @queue = TorqueBox::Messaging::Queue.new('foo')
      @queue.stub(:with_session).and_yield(@session)
    end

    context "normalizing options" do
      context "priority" do
        {
          :low => 1,
          :normal => 4,
          :high => 7,
          :critical => 9
        }.each do |symbol, level|
          it "should normalize :#{symbol} to #{level}" do
            @session.should_receive(:publish).with(anything, anything, { :priority => level })
            @queue.publish('message', { :priority => symbol })
          end
        end

        it "should pass through valid integer priorities" do
          @session.should_receive(:publish).with(anything, anything, { :priority => 5 })
          @queue.publish('message', { :priority => 5 })
        end

        it "should pass through valid integer-as-string priorities" do
          @session.should_receive(:publish).with(anything, anything, { :priority => 5 })
          @queue.publish('message', { :priority => "5" })
        end

        it "should raise on an invalid integer" do
          lambda { 
            @queue.publish('message', { :priority => -1 })
          }.should raise_error(ArgumentError)
        end
      end

      it "should handle persistence = true" do
        @session.should_receive(:publish).with(anything, anything, { :delivery_mode => javax.jms::DeliveryMode.PERSISTENT })
        @queue.publish('message', { :persistent => true })
      end

      it "should handle persistence = false" do
        @session.should_receive(:publish).with(anything, anything, { :delivery_mode => javax.jms::DeliveryMode.NON_PERSISTENT })
        @queue.publish('message', { :persistent => false })
      end
    end
  end

end
