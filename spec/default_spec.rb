# encoding: utf-8
require 'chefspec'
require 'spec_helper'
require 'chefspec/berkshelf'

describe 'mapr-spark::default' do
  let('chef_run') do
    ChefSpec::SoloRunner.new do |node|
    end.converge(described_recipe)
  end
  
  it 'installs package scala' do
    expect(chef_run).to install_package('http://www.scala-lang.org/files/archive/scala-2.10.4.rpm')
  end  
  
  it 'installs package mapr-spark' do
    expect(chef_run).to install_package('mapr-spark')
  end
  
  #ruby_block "Is Spark installed" do
  it 'check if spark was installeds' do
    expect(chef_run).to run_ruby_block('Is Spark installed')
  end
  
  it 'should edit yarn-site.xml' do
    expect(chef_run).to run_ruby_block('Add Property to yarn-site XML')
  end
end
