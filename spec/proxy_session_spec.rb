require File.dirname(__FILE__) + '/spec_helper.rb'

include RR

describe ProxySession do
  before(:each) do
    Initializer.configuration = standard_config
  end

  it "initialize should connect to the database" do
    session = ProxySession.new Initializer.configuration.left
    session.connection.active?.should == true
  end
  
  it "destroy should disconnect from the database" do
    session = ProxySession.new Initializer.configuration.left
    session.destroy

    session.connection.active?.should == false
  end
  
  it "primary_key_names should return the primary keys of the given table" do
    session = ProxySession.new Initializer.configuration.left
    
    session.primary_key_names('scanner_records').should == ['id']
  end
  
  it "cursors should return the current cursor hash or an empty hash if nil" do
    session = ProxySession.new Initializer.configuration.left
    session.cursors.should == {}
    session.cursors[:dummy_cursor] = :dummy_cursor
    session.cursors.should == {:dummy_cursor => :dummy_cursor}    
  end
  
  it "save_cursor should register the provided cursor" do
    session = ProxySession.new Initializer.configuration.left
    session.save_cursor :dummy_cursor
    
    session.cursors[:dummy_cursor].should == :dummy_cursor
  end
  
  it "destroy should destroy and unregister any stored cursors" do
    session = ProxySession.new Initializer.configuration.left
    
    cursor = mock("Cursor")
    cursor.should_receive(:destroy)
    
    session.save_cursor cursor
    session.destroy
    
    session.cursors.should == {}
  end

  it "destroy_cursor should destroy and unregister the provided cursor" do
    session = ProxySession.new Initializer.configuration.left
    
    cursor = mock("Cursor")
    cursor.should_receive(:destroy)
    
    session.save_cursor cursor
    session.destroy_cursor cursor
    
    session.cursors.should == {}
  end
  
  it "create_cursor should create and register the cursor and initiate row fetching" do
    session = ProxySession.new Initializer.configuration.left
    
    cursor = session.create_cursor(
      ProxyRowCursor, 
      'scanner_records',
      {'id' => 2},
      {'id' => 2}
    )

    cursor.should be_an_instance_of(ProxyRowCursor)
    cursor.next_row_keys_and_checksum[0].should == {'id' => 2} # verify that 'from' range was used
    cursor.next?.should be_false # verify that 'to' range was used
  end
  
  it "column_names should return the column names of the specified table" do
    session = ProxySession.new standard_config.left
    session.column_names('scanner_records').should == ['id', 'name']
  end
  
  it "primary_key_names should return the names of the primary keys of the specified table" do
    session = ProxySession.new standard_config.left
    session.primary_key_names('scanner_records').should == ['id']
  end
  
end