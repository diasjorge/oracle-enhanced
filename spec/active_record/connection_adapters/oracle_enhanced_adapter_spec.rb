require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe "OracleEnhancedAdapter establish connection" do
  
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
  end
  
  it "should connect to database" do
    ActiveRecord::Base.connection.should_not be_nil
    ActiveRecord::Base.connection.class.should == ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
  end
  
end

describe "OracleEnhancedAdapter schema dump" do
  
  before(:all) do
    @old_conn = ActiveRecord::Base.oracle_connection(
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @old_conn.class.should == ActiveRecord::ConnectionAdapters::OracleAdapter
    @new_conn = ActiveRecord::Base.oracle_enhanced_connection(
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @new_conn.class.should == ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
  end

  it "should return the same tables list as original oracle adapter" do
    @new_conn.tables.should == @old_conn.tables
  end

  it "should return the same pk_and_sequence_for as original oracle adapter" do
    @new_conn.tables.each do |t|
      @new_conn.pk_and_sequence_for(t).should == @old_conn.pk_and_sequence_for(t)
    end    
  end

  it "should return the same structure dump as original oracle adapter" do
    @new_conn.structure_dump.should == @old_conn.structure_dump
  end

  it "should return the same structure drop as original oracle adapter" do
    @new_conn.structure_drop.should == @old_conn.structure_drop
  end

end

describe "OracleEnhancedAdapter database session store" do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @conn = ActiveRecord::Base.connection
    @conn.execute <<-SQL
      CREATE TABLE sessions (
        id          NUMBER(38,0) NOT NULL,
        session_id  VARCHAR2(255) DEFAULT NULL,
        data        CLOB DEFAULT NULL,
        updated_at  DATE DEFAULT NULL,
        PRIMARY KEY (ID)
      )
    SQL
    @conn.execute <<-SQL
      CREATE SEQUENCE sessions_seq  MINVALUE 1 MAXVALUE 999999999999999999999999999
        INCREMENT BY 1 START WITH 10040 CACHE 20 NOORDER NOCYCLE
    SQL
  end

  after(:all) do
    @conn.execute "DROP TABLE sessions"
    @conn.execute "DROP SEQUENCE sessions_seq"
  end

  it "should create sessions table" do
    ActiveRecord::Base.connection.tables.grep("sessions").should_not be_empty
  end

  it "should save session data" do
    @session = CGI::Session::ActiveRecordStore::Session.new :session_id => "123456", :data  => "something", :updated_at => Time.now
    @session.save!
    @session = CGI::Session::ActiveRecordStore::Session.find_by_session_id("123456")
    @session.data.should == "something"
  end

end

describe "OracleEnhancedAdapter date type detection based on column names" do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @conn = ActiveRecord::Base.connection
    @conn.execute <<-SQL
      CREATE TABLE test_employees (
        employee_id   NUMBER(6,0),
        first_name    VARCHAR2(20),
        last_name     VARCHAR2(25),
        email         VARCHAR2(25),
        phone_number  VARCHAR2(20),
        hire_date     DATE,
        job_id        NUMBER(6,0),
        salary        NUMBER(8,2),
        commission_pct  NUMBER(2,2),
        manager_id    NUMBER(6,0),
        department_id NUMBER(4,0),
        created_at    DATE
      )
    SQL
    @conn.execute <<-SQL
      CREATE SEQUENCE test_employees_seq  MINVALUE 1
        INCREMENT BY 1 START WITH 10040 CACHE 20 NOORDER NOCYCLE
    SQL
  end
  
  after(:all) do
    @conn.execute "DROP TABLE test_employees"
    @conn.execute "DROP SEQUENCE test_employees_seq"
  end

  it "should set DATE column type as datetime if emulate_dates_by_column_name is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = false
    columns = @conn.columns('test_employees')
    column = columns.detect{|c| c.name == "hire_date"}
    column.type.should == :datetime
  end

  it "should set DATE column type as date if column name contains 'date' and emulate_dates_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = true
    columns = @conn.columns('test_employees')
    column = columns.detect{|c| c.name == "hire_date"}
    column.type.should == :date
  end

  it "should set DATE column type as datetime if column name does not contain 'date' and emulate_dates_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = true
    columns = @conn.columns('test_employees')
    column = columns.detect{|c| c.name == "created_at"}
    column.type.should == :datetime
  end

  it "should return Time value from DATE column if emulate_dates_by_column_name is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = false
    columns = @conn.columns('test_employees')
    column = columns.detect{|c| c.name == "hire_date"}
    column.type_cast(Time.now).class.should == Time
  end

  it "should return Date value from DATE column if column name contains 'date' and emulate_dates_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = true
    columns = @conn.columns('test_employees')
    column = columns.detect{|c| c.name == "hire_date"}
    column.type_cast(Time.now).class.should == Date
  end

  describe "/ DATE values from ActiveRecord model" do
    before(:all) do
      class TestEmployee < ActiveRecord::Base
        set_primary_key :employee_id
      end
    end

    before(:each) do
      @employee = TestEmployee.create(
        :first_name => "First",
        :last_name => "Last",
        :hire_date => Date.today,
        :created_at => Time.now
      )
    end

    it "should return Time value from DATE column if emulate_dates_by_column_name is false" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = false
      @employee.reload
      @employee.hire_date.class.should == Time
    end

    it "should return Date value from DATE column if column name contains 'date' and emulate_dates_by_column_name is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = true
      @employee.reload
      @employee.hire_date.class.should == Date
    end

    it "should return Time value from DATE column if column name does not contain 'date' and emulate_dates_by_column_name is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_dates_by_column_name = true
      @employee.reload
      @employee.created_at.class.should == Time
    end

  end

end

describe "OracleEnhancedAdapter integer type detection based on column names" do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @conn = ActiveRecord::Base.connection
    @conn.execute <<-SQL
      CREATE TABLE test2_employees (
        id   NUMBER,
        first_name    VARCHAR2(20),
        last_name     VARCHAR2(25),
        email         VARCHAR2(25),
        phone_number  VARCHAR2(20),
        hire_date     DATE,
        job_id        NUMBER,
        salary        NUMBER,
        commission_pct  NUMBER(2,2),
        manager_id    NUMBER(6),
        department_id NUMBER(4,0),
        created_at    DATE
      )
    SQL
    @conn.execute <<-SQL
      CREATE SEQUENCE test2_employees_seq  MINVALUE 1
        INCREMENT BY 1 START WITH 10040 CACHE 20 NOORDER NOCYCLE
    SQL
  end
  
  after(:all) do
    @conn.execute "DROP TABLE test2_employees"
    @conn.execute "DROP SEQUENCE test2_employees_seq"
  end

  it "should set NUMBER column type as decimal if emulate_integers_by_column_name is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = false
    columns = @conn.columns('test2_employees')
    column = columns.detect{|c| c.name == "job_id"}
    column.type.should == :decimal
  end

  it "should set NUMBER column type as integer if emulate_integers_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
    columns = @conn.columns('test2_employees')
    column = columns.detect{|c| c.name == "job_id"}
    column.type.should == :integer
    column = columns.detect{|c| c.name == "id"}
    column.type.should == :integer
  end

  it "should set NUMBER column type as decimal if column name does not contain 'id' and emulate_integers_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
    columns = @conn.columns('test2_employees')
    column = columns.detect{|c| c.name == "salary"}
    column.type.should == :decimal
  end

  it "should return BigDecimal value from NUMBER column if emulate_integers_by_column_name is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = false
    columns = @conn.columns('test2_employees')
    column = columns.detect{|c| c.name == "job_id"}
    column.type_cast(1.0).class.should == BigDecimal
  end

  it "should return Fixnum value from NUMBER column if column name contains 'id' and emulate_integers_by_column_name is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
    columns = @conn.columns('test2_employees')
    column = columns.detect{|c| c.name == "job_id"}
    column.type_cast(1.0).class.should == Fixnum
  end

  describe "/ NUMBER values from ActiveRecord model" do
    before(:each) do
      class Test2Employee < ActiveRecord::Base
      end
    end
    
    after(:each) do
      Object.send(:remove_const, "Test2Employee")
    end
    
    def create_employee2
      @employee2 = Test2Employee.create(
        :first_name => "First",
        :last_name => "Last",
        :job_id => 1,
        :salary => 1000
      )
      @employee2.reload
    end
    
    it "should return BigDecimal value from NUMBER column if emulate_integers_by_column_name is false" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = false
      create_employee2
      @employee2.job_id.class.should == BigDecimal
    end

    it "should return Fixnum value from NUMBER column if column name contains 'id' and emulate_integers_by_column_name is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      create_employee2
      @employee2.job_id.class.should == Fixnum
    end

    it "should return BigDecimal value from NUMBER column if column name does not contain 'id' and emulate_integers_by_column_name is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      create_employee2
      @employee2.salary.class.should == BigDecimal
    end

  end

end

describe "OracleEnhancedAdapter boolean type detection based on string column types and names" do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @conn = ActiveRecord::Base.connection
    @conn.execute <<-SQL
      CREATE TABLE test3_employees (
        id            NUMBER,
        first_name    VARCHAR2(20),
        last_name     VARCHAR2(25),
        email         VARCHAR2(25),
        phone_number  VARCHAR2(20),
        hire_date     DATE,
        job_id        NUMBER,
        salary        NUMBER,
        commission_pct  NUMBER(2,2),
        manager_id    NUMBER(6),
        department_id NUMBER(4,0),
        created_at    DATE,
        has_email     CHAR(1),
        has_phone     VARCHAR2(1),
        active_flag   VARCHAR2(2),
        manager_yn    VARCHAR2(3)
      )
    SQL
    @conn.execute <<-SQL
      CREATE SEQUENCE test3_employees_seq  MINVALUE 1
        INCREMENT BY 1 START WITH 10040 CACHE 20 NOORDER NOCYCLE
    SQL
  end
  
  after(:all) do
    @conn.execute "DROP TABLE test3_employees"
    @conn.execute "DROP SEQUENCE test3_employees_seq"
  end

  it "should set CHAR/VARCHAR2 column type as string if emulate_booleans_from_strings is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = false
    columns = @conn.columns('test3_employees')
    %w(has_email has_phone active_flag manager_yn).each do |col|
      column = columns.detect{|c| c.name == col}
      column.type.should == :string
    end
  end

  it "should set CHAR/VARCHAR2 column type as boolean if emulate_booleans_from_strings is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = true
    columns = @conn.columns('test3_employees')
    %w(has_email has_phone active_flag manager_yn).each do |col|
      column = columns.detect{|c| c.name == col}
      column.type.should == :boolean
    end
  end
  
  it "should set VARCHAR2 column type as string if column name does not contain 'flag' or 'yn' and emulate_booleans_from_strings is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = true
    columns = @conn.columns('test3_employees')
    %w(phone_number email).each do |col|
      column = columns.detect{|c| c.name == col}
      column.type.should == :string
    end
  end
  
  it "should return string value from VARCHAR2 boolean column if emulate_booleans_from_strings is false" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = false
    columns = @conn.columns('test3_employees')
    %w(has_email has_phone active_flag manager_yn).each do |col|
      column = columns.detect{|c| c.name == col}
      column.type_cast("Y").class.should == String
    end
  end
  
  it "should return boolean value from VARCHAR2 boolean column if emulate_booleans_from_strings is true" do
    ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = true
    columns = @conn.columns('test3_employees')
    %w(has_email has_phone active_flag manager_yn).each do |col|
      column = columns.detect{|c| c.name == col}
      column.type_cast("Y").class.should == TrueClass
      column.type_cast("N").class.should == FalseClass
    end
  end
  
  describe "/ VARCHAR2 boolean values from ActiveRecord model" do
    before(:each) do
      class Test3Employee < ActiveRecord::Base
      end
    end
    
    after(:each) do
      Object.send(:remove_const, "Test3Employee")
    end
    
    def create_employee3
      @employee3 = Test3Employee.create(
        :first_name => "First",
        :last_name => "Last",
        :has_email => true,
        :has_phone => false,
        :active_flag => true,
        :manager_yn => false
      )
      @employee3.reload
    end
    
    it "should return String value from VARCHAR2 boolean column if emulate_booleans_from_strings is false" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = false
      create_employee3
      %w(has_email has_phone active_flag manager_yn).each do |col|
        @employee3.send(col.to_sym).class.should == String
      end
    end
  
    it "should return boolean value from VARCHAR2 boolean column if emulate_booleans_from_strings is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = true
      create_employee3
      %w(has_email active_flag).each do |col|
        @employee3.send(col.to_sym).class.should == TrueClass
        @employee3.send((col+"_before_type_cast").to_sym).should == "Y"
      end
      %w(has_phone manager_yn).each do |col|
        @employee3.send(col.to_sym).class.should == FalseClass
        @employee3.send((col+"_before_type_cast").to_sym).should == "N"
      end
    end
      
    it "should return string value from VARCHAR2 column if it is not boolean column and emulate_booleans_from_strings is true" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_booleans_from_strings = true
      create_employee3
      @employee3.first_name.class.should == String
    end
  
  end

end


describe "OracleEnhancedAdapter Bignum IDs" do
  before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => "oracle_enhanced",
                                            :database => "xe",
                                            :username => "hr",
                                            :password => "hr")
    @conn = ActiveRecord::Base.connection
    @conn.execute <<-SQL
      CREATE TABLE test4_employees (
        id            NUMBER,
        first_name    VARCHAR2(20),
        last_name     VARCHAR2(25),
        email         VARCHAR2(25),
        phone_number  VARCHAR2(20),
        hire_date     DATE,
        job_id        NUMBER,
        salary        NUMBER,
        commission_pct  NUMBER(2,2),
        manager_id    NUMBER(6),
        department_id NUMBER(4,0),
        created_at    DATE
      )
    SQL
    @conn.execute <<-SQL
      CREATE OR REPLACE
      TRIGGER TEST4_EMPLOYEES_T1
      BEFORE INSERT ON TEST4_EMPLOYEES
      REFERENCING NEW AS new 
      FOR EACH ROW 
      BEGIN
        IF :new.id IS NULL THEN
          SELECT to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' )
          INTO :new.id
          FROM dual;
        END IF;
      END;
    SQL
  end
  
  after(:all) do
    @conn.execute "DROP TABLE test4_employees"
  end


  describe "/ NUMBER values from ActiveRecord model" do
    before(:each) do
      class Test4Employee < ActiveRecord::Base
        set_sequence_name 'autogenerated'
      end
    end
    
    after(:each) do
      Object.send(:remove_const, "Test4Employee")
    end
    
    def create_employee4
      # @employee4 = Test4Employee.create(
      #   :first_name => "First",
      #   :last_name => "Last",
      #   :job_id => 1,
      #   :salary => 1000
      # )
      # @employee4.reload
      @conn.execute <<-SQL
        INSERT INTO test4_employees (
          first_name,
          last_name,
          job_id,
          salary
        ) VALUES (
          'First',
          'Last',
          1,
          1000.55
        )
      SQL
      @employee4 = Test4Employee.find(:first)
    end
    
    def ar_create_employee4
      @employee4 = Test4Employee.create(
        :first_name => "Test",
        :last_name => "Test",
        :job_id => 1,
        :salary => 1000
      )
    end

    def get_raw_employee4_id
      @conn.raw_connection.exec("SELECT id FROM test4_employees") {|r| return r[0]}
    end
    
    it "should return BigDecimal value from NUMBER column if emulate_integers_by_column_name is false" do
      OCI8::BindType::Mapping[:number_unknown_prec] = OCI8::BindType::OraNumber
      OCI8::BindType::Mapping[:number_no_prec_setting] = OCI8::BindType::OraNumber

      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = false
      create_employee4
      @employee4.id.class.should == BigDecimal
    end

    it "should return Bignum value from NUMBER column if column name contains 'id' and emulate_integers_by_column_name is true" do
      OCI8::BindType::Mapping[:number_unknown_prec] = OCI8::BindType::OraNumber
      OCI8::BindType::Mapping[:number_no_prec_setting] = OCI8::BindType::OraNumber

      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      create_employee4
      @employee4.id.class.should == Bignum
      get_raw_employee4_id.class.should == OraNumber
      Test4Employee.find(@employee4.id).id.should == @employee4.id
    end
    
    it "should return BigDecimal value from NUMBER column if column name does not contain 'id' and emulate_integers_by_column_name is true" do
      OCI8::BindType::Mapping[:number_unknown_prec] = OCI8::BindType::OraNumber
      OCI8::BindType::Mapping[:number_no_prec_setting] = OCI8::BindType::OraNumber

      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      create_employee4
      @employee4.salary.should == BigDecimal.new("1000.55")
      @employee4.salary.class.should == BigDecimal
    end

    it "should create new record using ActiveRecord and database trigger generated ID" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do
        alias_method :orig_prefetch_primary_key?, :prefetch_primary_key?
        def prefetch_primary_key?(table_name = nil)
          false
        end
      end
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      ar_create_employee4
      @employee4 = Test4Employee.find_by_first_name("Test")
      @employee4.first_name.should == "Test"
      @employee4.id.class.should == Bignum
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do
        alias_method :prefetch_primary_key?, :orig_prefetch_primary_key?
      end
    end

    it "should create new record using ActiveRecord and custom ID generation method" do
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do
        alias_method :orig_next_sequence_value, :next_sequence_value
        def next_sequence_value(sequence_name)
          if sequence_name == 'autogenerated'
            id = 0
            @connection.exec("SELECT to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' ) FROM dual") { |r| id = r[0].to_i }
            id
          else
            orig_next_sequence_value(sequence_name)
          end
        end
      end
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.emulate_integers_by_column_name = true
      ar_create_employee4
      @employee4.reload
      @employee4.first_name.should == "Test"
      @employee4.id.class.should == Bignum
      ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class_eval do
        alias_method :next_sequence_value, :orig_next_sequence_value
      end
    end

  end

end
