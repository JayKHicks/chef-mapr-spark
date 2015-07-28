#
# Cookbook Name:: mapr-spark
# Recipe:: default
#
# Copyright 2015, Gannett
#
# All rights reserved - Do Not Redistribute
#

# Install spark

if node['mapr']['spark_type'] == 'yarn'
  print "\n\nStarting Spark Yarn deployment\n\n"

  spark_home = ''

  package 'http://www.scala-lang.org/files/archive/scala-2.10.4.rpm'
  package 'mapr-spark'

  ruby_block 'Is Spark installed' do
    block do
      cmd = Mixlib::ShellOut.new('yum list installed |grep mapr-spark[^-]')
      cmd.run_command
      cmd.error!
      s_installed = cmd.stdout
      spark_is_installed = /mapr-spark/.match(s_installed)
      if spark_is_installed == 'mapr-spark'
        node.normal['mapr']['spark_installed'] = 'yes'
        cmd = Mixlib::ShellOut.new('ls /opt/mapr/spark')
        cmd.run_command
        cmd.error!
        spark_home = cmd.stdout.rstrip

        # Put entry in /etc/profile
        cmd = Mixlib::ShellOut.new("cat /etc/profile|grep SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}")
        cmd.run_command
        cmd.error!
        spark_home_grep = cmd.stdout.rstrip
        if spark_home_grep != "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
          open('/etc/profile', 'a') do |f|
            f.puts "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
          end
        end

        # Edit spark-defaults to add history server address to each host
        file = Chef::Util::FileEdit.new("#{node['mapr']['home']}/spark/#{spark_home}/conf/spark-defaults.conf")
        file.search_file_replace_line('/spark\.yarn\.historyServer\.address/',
                                      "spark.yarn.historyServer.address   http://#{node['mapr']['spark_history']}:18080")
        file.write_file
      end
    end
  end

  ruby_block 'Add Property to yarn-site XML' do
    block do
      # Put appropriate information in yarn-site.xml
      property_str = <<-EOS
<!-- BEGIN: Spark Installation settings -->
  <property>
    <name>yarn.application.classpath</name>
    <value>/opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop,
      /opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop,
      /opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/common/lib/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/common/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/hdfs,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/hdfs/lib/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/hdfs/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/yarn/lib/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/yarn/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/mapreduce/lib/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/mapreduce/*,
      /contrib/capacity-scheduler/*.jar,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/yarn/*,
      /opt/mapr/hadoop/hadoop-2.5.1/share/hadoop/yarn/lib/*
    </value>
  </property>
<!--  END: Spark Installation settings -->
</configuration>
      EOS

      file  = Chef::Util::FileEdit.new('/opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop/yarn-site.xml')
      # normalize the file removing any previously added properties
      file.search_file_replace('/<!-- BEGIN: Spark Installation settings -->.*?<!--  END: Spark Installation settings -->/m', '')
      file.search_file_replace_line('</configuration>', property_str)
      file.write_file
    end
    # only_if { File.exist?('/opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop/yarn-site.xml') }
  end

  # Install Spark history server on appropriate node with the fully qualified domain name
  if node['mapr']['spark_history'] == node['fqdn']
    package 'mapr-spark-historyserver'
    ruby_block 'Make Spark History Server directories' do
      block do
        cmd = Mixlib::ShellOut.new('hadoop fs -mkdir /apps/spark')
        cmd.run_command
        cmd.error!

        cmd = Mixlib::ShellOut.new('hadoop fs -chmod 777 /apps/spark')
        cmd.run_command
        cmd.error!

        cmd = Mixlib::ShellOut.new("/opt/mapr/spark/#{spark_home}/sbin/start-history-server.sh")
        cmd.run_command
        cmd.error!
      end
    end
  end
  print "\n\nFinished Spark Yarn deployment\n\n"
else
  print "\n\nStarting Spark Standalone installation\n\n"

  spark_home = ''
  package 'mapr-spark'

  ruby_block 'Is Spark installed' do
    block do
      cmd = Mixlib::ShellOut.new('yum list installed |grep mapr-spark[^-]')
      cmd.run_command
      cmd.error!
      spark_is_installed = /mapr-spark/.match(s_installed)
      if spark_is_installed == 'mapr-spark'
        node.normal['mapr']['spark_installed'] = 'yes'
      end

      # Find spark version number for spark_home
      cmd = Mixlib::ShellOut.new('ls /opt/mapr/spark')
      cmd.run_command
      cmd.error!
      spark_home = cmd.stdout.rstrip

      cmd = Mixlib::ShellOut.new("cat /etc/profile|grep SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}")
      cmd.run_command
      cmd.error!
      spark_home_grep = cmd.stdout.rstrip

      # Put entry in /etc/profile
      if spark_home_grep != "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
        open('/etc/profile', 'a') do |f|
          f.puts "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
        end
      end

      # Edit spark-defaults to add history server address to each host
      file = Chef::Util::FileEdit.new("#{node['mapr']['home']}/spark/#{spark_home}/conf/spark-defaults.conf")
      file.search_file_replace_line("spark\.yarn\.historyServer\.address   http\:\/\/\<hostname\>",
                                    "spark.yarn.historyServer.address   http://#{node['mapr']['spark_history']}:18080")
      file.write_file
    end
  end

  # Install Spark history server on appropriate node
  if node['mapr']['spark_history'] == node['fqdn']
    package 'mapr-spark-historyserver'
    ruby_block 'Make Spark History Server directories' do
      block do
        cmd = Mixlib::ShellOut.new('hadoop fs -mkdir /apps/spark')
        cmd.run_command
        cmd.error!
        cmd = Mixlib::ShellOut.new('hadoop fs -chmod 777 /apps/spark')
        cmd.run_command
        cmd.error!
      end
    end
  end

  if node['mapr']['spark_master'] == node['fqdn']
    package 'mapr-spark-master'
    ruby_block 'Configure Spark Master' do
      block do
        # Enter all Spark Workers into file, we're assuming all MapR nodes are to be workers...
        file = Chef::Util::FileEdit.new("#{node['mapr']['home']}/spark/#{spark_home}/conf/slaves")
        file.search_file_delete_line('localhost')
        node['mapr']['cluster_nodes'].each do |nodeX|
          file.insert_line_if_no_match(nodeX, nodeX)
        end
        file.write_file
      end
    end

    # NOTE:  THIS BLOCK IS AN INFINITE LOOP IF A NODE INSTALL FAILS...
    # WE ARE ASSUMING THAT ALL NODES WILL SUCCEED IN INSTALLING,
    # SO FAILURE WILL REQUIRE KILLING OFF THE CLIENT RUNNING ON THE MASTER...
    ruby_block 'Wait for all spark workers to finish installing, then start Spark Master' do
      block do
        installed_count = '0'
        is_installed = 'no'
        while installed_count.to_s != node['mapr']['node_count'].to_s
          node['mapr']['cluster_nodes'].each do |nodeX|
            is_installed = 'no'
            while is_installed.to_s != 'mapr-spark'

              cmd = Mixlib::ShellOut.new("ssh #{nodeX} yum list installed|grep mapr-spark[^-]")
              cmd.run_command
              cmd.error!
              mapr_sparl_list = cmd.stdout.rstrip

              is_installed = /mapr-spark/.match(mapr_sparl_list)
              if is_installed.to_s == 'mapr-spark'
                installed_count = installed_count.to_i + 1
                print "\nNode #{nodeX} has completed Spark Worker Installation"
              else
                cmd = Mixlib::ShellOut.new('sleep 5')
                cmd.run_command
                cmd.error!
                print "\nWaiting on node #{nodeX}\n"
              end
            end
          end
        end
        print "\n\nAll #{node['mapr']['node_count']} nodes have finished installing Spark Workers...starting Spark Workers \n"
        cmd = Mixlib::ShellOut.new("#{node['mapr']['home']}/spark/#{spark_home}/sbin/start-slaves.sh")
        cmd.run_command
        cmd.error!
      end
    end
  end
end
