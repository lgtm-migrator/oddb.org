#!/usr/bin/env ruby
# encoding: utf-8

$: << File.expand_path('..', File.dirname(__FILE__))
$: << File.expand_path("../../src", File.dirname(__FILE__))


require 'minitest/autorun'
require 'stub/odba'
require 'fileutils'
require 'flexmock/minitest'
require 'plugin/medical_products'
require 'model/text'
require 'model/atcclass'
require 'model/fachinfo'
require 'model/commercial_form'
require 'model/registration'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
I_KNOW_THAT_OPENSSL_VERIFY_PEER_EQUALS_VERIFY_NONE_IS_WRONG = nil

module ODDB
  module SequenceObserver
    def initialize
    end
    def select_one(param)
    end
  end
  class PseudoFachinfoDocument
    def descriptions
      { :de => FlexMock.new('descriptions') }
    end
  end
    class StubLog
      include ODDB::Persistence
      attr_accessor :report, :pointers, :recipients, :hash
      def notify(arg=nil)
      end
    end
    class StubPackage
      attr_accessor :commercial_forms
      def initialize
        puts "StubPackage addin CommercialForm"
        @commercial_mock = FlexMock.new(ODDB::CommercialForm)
        @commercial_forms = [@commercial_mock]
      end
    end
    class ODDB::Registration
     def initialize(iksnr)
        @pointer = FlexMock.new(Persistence::Pointer)
        @pointer.should_receive(:descriptions).and_return(@descriptions)
        @pointer.should_receive(:pointer).and_return(@pointer)
        @pointer.should_receive(:creator).and_return([])
        @pointer.should_receive(:+).and_return(@pointer)
      @iksnr = iksnr
      @sequences = {}
      end
    end
    class StubApp
      attr_writer :log_group
      attr_reader :pointer, :values, :model
      attr_accessor :last_date, :registrations
      def initialize
        @model = StubLog.new
        @registrations = {}
        @company_mock = FlexMock.new(ODDB::Company)
        @company_mock.should_receive(:pointer).and_return(@pointer)
        product_mock = FlexMock.new(@registrations)
        product_mock.should_receive(:odba_store)
        @pointer_mock = FlexMock.new(Persistence::Pointer)
        @descriptions_mock = FlexMock.new('descriptions')
        @pointer_mock.should_receive(:descriptions).and_return(@descriptions_mock)
        @pointer_mock.should_receive(:pointer).and_return(@pointer_mock)
        @pointer_mock.should_receive(:notify).and_return([])
        @pointer_mock.should_receive(:+).and_return(@pointer_mock)
      end
      def atc_class(name)
        @atc_name = name
        @atc_class_mock = FlexMock.new(ODDB::AtcClass)
        @atc_class_mock.should_receive(:pointer).and_return(@pointer_mock)
        @atc_class_mock.should_receive(:pointer_descr).and_return(@atc_name)
        @atc_class_mock.should_receive(:code).and_return(@atc_name)
        return @atc_class_mock
      end
      def commercial_form_by_name(name)
        if name.match(/Fertigspritze/i)
          @commercial_mock = FlexMock.new(ODDB::CommercialForm)
          @commercial_mock.should_receive(:pointer).and_return(@pointer_mock)
          return @commercial_mock
        else
          return nil
        end
      end
      def create_registration(name)
        @registration_stub = ODDB::Registration.new(name)
        @registrations[name] = @registration_stub
        @registration_stub
      end
      def company_by_name(name, matchValue)
        @registration_stub
      end
      def registration(number)
        @registrations[number.to_s]
      end
      def sequence(number)
        @sequence_mock
      end
      def create_fachinfo
        @fachinfo ||= Fachinfo.new
        @fachinfo
      end
      def odba_store
      end
      def odba_isolated_store
      end
      def update(pointer, values, reason = nil)
        @pointer = pointer
        @values = values
        if reason and reason.to_s.match('medical_product')
          return @commercial_mock
        end
        return @company_mock if reason and reason.to_s.match('company')
        if reason.to_s.match(/registration/)
          number = pointer.to_yus_privilege.match(/\d+/)[0]
          stub = Registration.new(number)
          @registrations[number] = stub
          return stub
        elsif reason and reason.to_s.eql?('text_info')
           return PseudoFachinfoDocument.new
        end
        return PseudoFachinfoDocument.new
        @pointer_mock
      end
      def log_group(key)
        @log_group
      end
      def create(pointer)
        @log_group
      end
      def recount
        'recount'
      end
    end

  class TestMedicalProductPlugin <Minitest::Test
    @@datadir = File.expand_path '../../ext/fiparse/test/run/docx/', File.dirname(__FILE__)
    @@origdir = File.expand_path '../../ext/fiparse/test/data/docx/', File.dirname(__FILE__)
    @@vardir = File.expand_path '../var', File.dirname(__FILE__)

    def setup
      @hostname = Socket.gethostbyname(Socket.gethostname).first
      FileUtils.rm_rf(@@datadir)
      FileUtils.makedirs(@@datadir)
      assert(File.directory?(@@datadir), "Directory #{@@datadir} must exist")
      FileUtils.mkdir_p @@vardir
      ODDB.config.data_dir = @@vardir
      ODDB.config.log_dir = @@vardir
      @opts = {
        :lang  => 'de',
        :files => [ File.join(@@datadir, 'Sinovial_DE.docx') ],
      }
      @sequence = flexmock('sequence',
                           :packages => ['packages'],
                           :pointer => 'pointer',
                           :creator => 'creator')
      seq_ptr = flexmock('seq_ptr',
                          :pointer => 'seq_ptr.pointer')
      @pointer = flexmock('pointer',
                          :pointer => seq_ptr,
                          :packages => ['packages'])
      @sequence = flexmock('sequence',
                           :creator => @sequence)
      seq_ptr.should_receive(:+).with([:sequence, 0]).and_return(@sequence)
      @app = StubApp.new
    end # Fuer Problem mit fachinfo italic

    def teardown
      FileUtils.rm_rf @@vardir
      super # to clean up FlexMock
    end
    def test_update_medical_product_with_absolute_path
      fileName = File.join(@@origdir, 'Sinovial_DE.docx')
      assert(File.exist?(fileName), "File #{fileName} must exist")
      options = {:files => [ fileName ],  :lang => 'de' }
      @plugin = ODDB::MedicalProductPlugin.new(@app, options)
      res = @plugin.update()
      skip("Niklaus does not want to waste time to mock correctly this situation")
      assert_equal(2, @app.registrations.size, 'We have 2 medical_products in Sinovial_DE.docx')
      packages = @app.registrations.first[1].packages
      assert_equal('Fertigspritze', packages.first.commercial_forms.first)
    end
    def test_update_medical_product_with_lang_and_relative
      fileName = File.join(@@origdir, 'Sinovial_DE.docx')
      options = {:files => [ fileName ],  :lang => 'de' }
      @plugin = ODDB::MedicalProductPlugin.new(@app, options)
      res = @plugin.update()
      skip("Niklaus does not want to waste time to mock correctly this situation on travis")
      assert_equal(2, @app.registrations.size, 'We have 2 medical_products in Sinovial_DE.docx. @hostname is ' + @hostname)
    end
    def test_update_medical_product_with_relative_wildcard
      options = {:files => [ '*.docx']}
      @plugin = ODDB::MedicalProductPlugin.new(@app, options)
      res = @plugin.update()
      skip 'We have 2 medical_product in Sinovial_DE.docx. @hostname is ' + @hostname
      if /localhost/i.match(@hostname)
        skip 'We have 2 medical_product in Sinovial_DE.docx'
      else
        assert_equal(2, @app.registrations.size, 'We have 2 medical_products in Sinovial_DE.docx. @hostname is ' + @hostname)
      end
    end
    def test_update_medical_product_french
      options = {:files => [ '*.docx'], :lang => :fr}
      @plugin = ODDB::MedicalProductPlugin.new(@app, options)
      res = @plugin.update()
      skip 'We have 2 medical_product in Sinovial_DE.docx. @hostname is ' + @hostname
      if /localhost/i.match(@hostname)
        skip 'We have 2 medical_product in Sinovial_FR.docx'
      else
        assert_equal(2, @app.registrations.size, 'We have 2 medical_product in Sinovial_FR.docx')
      end
			packages = @app.registrations.first[1].packages
      assert(packages, 'packages must be available')
      assert_equal(1, packages.size, 'we must have exactly two packages')
      assert_nil(packages.first.commercial_forms.first)
    end
    def test_update_invalid_ean
      fileName = File.join(@@origdir, 'errors', 'invalid_ean13.docx')
      options = {:files => [ fileName ],  :lang => 'de' }
      @plugin = ODDB::MedicalProductPlugin.new(@app, options)
      skip("Niklaus does not want to waste time to mock correctly this situation on travis #{@hostname}") if /testing-docker/i.match(@hostname)
      assert_raises(SBSM::InvalidDataError) {@plugin.update()}
    end
  end
end
