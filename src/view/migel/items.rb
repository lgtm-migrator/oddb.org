#!/usr/bin/env ruby
# encoding: utf-8
# ODDB::View::Migel::Items -- oddb.org -- 28.09.2011 -- mhatakeyama@ywesee.com

require 'htmlgrid/list'
require 'htmlgrid/link'
require 'view/additional_information'
require 'view/dataformat'
require 'view/pager'

module ODDB
  module View
    module Migel

class SubHeader < HtmlGrid::Composite
  include View::AdditionalInformation
  include View::DataFormat
  COMPONENTS = {
    [0,0,0] => :max_insure_value,
    [0,0,1] => :price,
    [0,0,2] => :qty_unit,
    [0,0,3] => ' MiGel Code: ',
    [0,0,4] => :migel_code,
    [1,0]   => :pages,
  }
	CSS_CLASS = 'composite'
  CSS_MAP = {
    [0,0] => 'subheading',
    [1,0] => 'subheading',
  }
  def max_insure_value(model = @model, session = @session)
    if session.language == 'de'
      'Höchstvergütungsbetrag: '
    else
      'Montants Maximaux: '
    end
  end
  def migel_code(model=@model, session=@session)
    link = HtmlGrid::Link.new(:to_s, @model, @session, self)
    key_value = {:migel_code => model.migel_code}
    event = :migel_search
    link.href = @lookandfeel._event_url(event, key_value)
    link.value = model.migel_code
    link
  end
  def pages(model, session=@session)

    pages = @session.state.pages
    event = ''
    args  = {}
    if migel_code = @session.user_input(:migel_code)
      event = :migel_search
      args.update({:migel_code => migel_code})
    else
      event = :search
      args.update({
        :search_query => @session.persistent_user_input(:search_query).gsub('/', '%2F'),
        :search_type => @session.persistent_user_input(:search_type),
      })
    end

    # sort
    sortvalue = @session.user_input(:sortvalue) || @session.user_input(:reverse)
    sort_way = @session.user_input(:sortvalue) ? :sortvalue : :reverse
    if sortvalue
      args.update({sort_way => sortvalue})
    end

    View::Pager.new(pages, @session, self, event, args)
  end
end

class SearchedList < HtmlGrid::List
	CSS_CLASS = 'composite'
  SUBHEADER = ODDB::View::Migel::SubHeader
  def init
    @components = {
      [0,0]		=>	:pharmacode,
      [1,0]		=>	:ean_code,
      [2,0]		=>	:article_name,
      [3,0]		=>	:size,
      [4,0]		=>	:status,
      [5,0]		=>	:companyname,
    #  [6,0]		=>	:ppha,
      [6,0]		=>	:ppub,
    #  [8,0]		=>	:factor,
    }
    @css_map = {
      [0,0]   => 'list',
      [1,0]   => 'list',
      [2,0]   => 'list bold',
      [3,0]   => 'list italic',
      [4,0]   => 'list',
      [5,0]   => 'list',
      [6,0]   => 'list',
    #  [7,0]   => 'list',
    #  [8,0]   => 'list',
    }
    super
  end
  def article_name(model = @model, session = @session)
    if model.article_name.respond_to?(session.language)
      model.article_name.send(session.language)
    else
      model.article_name
    end
  end
  def companyname(model = @model, session = @session)
    if model.companyname.respond_to?(session.language)
      model.companyname.send(session.language)
    else
      model.companyname
    end
  end
  def size(model = @model, session = @session)
    if model.size.respond_to?(session.language)
      model.size.send(session.language)
    else
      model.size
    end
  end
  def compose_list(model = @model, offset=[0,0])
    # Grouping products with migel_code
    migel_code_group = {}
    model.each do |product|
      (migel_code_group[product.migel_code] ||= []) <<  product
    end

    # list up items
    migel_code_group.keys.sort.each do |migel_code|
      offset_length = migel_code_group[migel_code].length
      compose_subheader(migel_code_group[migel_code][0], offset)
      super(migel_code_group[migel_code], offset)
      offset[1] += offset_length
    end
  end
  def compose_subheader(item, offset, css='list atc')
    subheader = SubHeader.new(item, @session, self)
    @grid.add(subheader, *offset)
    @grid.set_colspan(offset.at(0), offset.at(1), full_colspan)
    offset[1] += 1
  end
  def sort_link(header_key, matrix, component)
    link = HtmlGrid::Link.new(header_key, @model, @session, self)

    sortvalue = @session.user_input(:sortvalue) || @session.user_input(:reverse)
    sort_way = @session.user_input(:sortvalue) ? :sortvalue : :reverse
    sort_way = if sort_way == :sortvalue and component.to_s == sortvalue
                 :reverse
               else
                 :sortvalue
               end
    page = @session.user_input(:page)
    if search_query = @session.user_input(:search_query)
      args = [:zone, @session.zone, :search_query, @session.user_input(:search_query), sort_way, component.to_s]
      if page
        args.concat [:page, page+1]
      end
      link.href = @lookandfeel._event_url(@session.event, args)
    elsif @model.first
      args = [:migel_code, @model.first.migel_code.gsub('.',''), sort_way, component.to_s]
      if page
        args.concat [:page, page+1]
      end
      link.href = @lookandfeel._event_url(:migel_search, args)
    end
    link
  end
end
class SearchedComposite < HtmlGrid::Composite
  COMPONENTS = {
    [0,0] => SearchedList,
  }
	CSS_CLASS = 'composite'
end
class Items < View::PrivateTemplate
  CONTENT = SearchedComposite
  SNAPBACK_EVENT = :result
end
    end
  end
end