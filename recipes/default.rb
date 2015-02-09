#
# Cookbook Name:: mapr_spark_installation
# Recipe:: default
#
# Copyright 2015, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#

#Install spark

install_pack = ""
if node['mapr']['spark_type'] == "yarn" 
    print "\n\nStarting Spark Yarn deployment\n\n"
    scala_installed = "no"
    ruby_block "Installing Scala" do
        block do
            #install scala
            `rpm -ivh http://www.scala-lang.org/files/archive/scala-2.10.3.rpm`
	    #Get spark package
            if  ! File.exist?('/opt/spark-1.1.0-bin-2.5.1-mapr-1501.tar')
                `wget -P /opt http://package.mapr.com/labs/spark/spark-1.1.0-bin-2.5.1-mapr-1501.tar`
	    end
	    #Make scala dir
            if ! Dir.exist?("/opt/mapr/spark")
               `mkdir /opt/mapr/spark`
            end
            #Unpack spark
            `tar xvzf /opt//spark-1.1.0-bin-2.5.1-mapr-1501.tar -C /opt/mapr/spark` 
	    
            #Alter spark-defaults file for all clients
            file  = Chef::Util::FileEdit.new("/opt/mapr/spark/spark-1.1.0-bin-2.5.1-mapr-1501/conf/spark-defaults.conf")
            file.search_file_replace_line("spark\.yarn\.historyServer\.address   http\:\/\/\<hostname\>","spark.yarn.historyServer.address   http://ip-172-16-2-225.ec2.internal:18080")
            file.write_file

            #Put appropriate information in yarn-site.xml
            file  = Chef::Util::FileEdit.new("/opt/mapr/hadoop/hadoop-2.5.1/etc/hadoop/yarn-site.xml")
            file.insert_line_after_match("CAUTION::: DO NOT EDIT ANYTHING ON OR ABOVE THIS LINE -->", "
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
")
	    #Ensure that the above is only inserted once in case this is rerun...
            file.search_file_replace_line("CAUTION::: DO NOT EDIT ANYTHING ON OR ABOVE THIS LINE -->","  <!-- :::CAUTION::: DON'T EDIT ANYTHING ON OR ABOVE THIS LINE -->")
            file.write_file
  
            #Make  historyserver dirs and start Spark History Server
            if node["mapr"]["spark_history"] == node['fqdn']
                 `hadoop fs -mkdir /apps/spark`
                 `hadoop fs -chmod 777 /apps/spark`
                 `/opt/mapr/spark/spark-1.1.0-bin-2.5.1-mapr-1501/sbin/start-history-server.sh`
            end
        end
    end
else
    print "\n\nStarting Spark Standalone installation\n\n"

    spark_home = ""
    package 'mapr-spark'

    ruby_block "Is Spark installed" do
        block do
            s_installed = `yum list installed |grep mapr-spark[^-]`
            spark_is_installed = /mapr-spark/.match(s_installed)
            if spark_is_installed == "mapr-spark"
                node['mapr']['spark_installed'] = "yes"
            end

            #Find spark version number for spark_home
            spark_home = `ls /opt/mapr/spark`.rstrip

	    #Put entry in /etc/profile
            if `cat /etc/profile|grep SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}`.rstrip != "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
                open('/etc/profile', 'a') { |f|
                    f.puts "export SPARK_HOME=#{node['mapr']['home']}/spark/#{spark_home}"
                } 
            end

	    # Edit spark-defaults to add history server address to each host
            file = Chef::Util::FileEdit.new("#{node['mapr']['home']}/spark/#{spark_home}/conf/spark-defaults.conf")
            file.search_file_replace_line("spark\.yarn\.historyServer\.address   http\:\/\/\<hostname\>","spark.yarn.historyServer.address   http://#{node['mapr']['spark_master']}:18080")
            file.write_file
        end
    end

    # Install Spark historserver on appropriate node
    if node["mapr"]["spark_history"] == node['fqdn']
        package 'mapr-spark-historyserver'
        ruby_block "Make Spark History Server directories" do
            block do
                `hadoop fs -mkdir /apps/spark`
                `hadoop fs -chmod 777 /apps/spark`
            end
        end
    end
 
    if node['mapr']['spark_master'] == node['fqdn']
        package 'mapr-spark-master'
        ruby_block "Configure Spark Master" do
            block do
		    # Enter all Spark Workers into file, we're assuming all MapR nodes are to be workers...
                    file = Chef::Util::FileEdit.new("#{node['mapr']['home']}/spark/#{spark_home}/conf/slaves")
                    file.search_file_delete_line("localhost")
                    node["mapr"]["cluster_nodes"].each do |nodeX| 
                        file.insert_line_if_no_match("#{nodeX}","#{nodeX}")
                    end
	            file.write_file
            end
        end

        # NOTE:  THIS BLOCK IS AN INFINITE LOOP IF A NODE INSTALL FAILS...
        # WE ARE ASSUMING THAT ALL NODES WILL SUCCEED IN INSTALLING,
        # SO FAILURE WILL REQUIRE KILLING OFF THE CLIENT RUNNING ON THE MASTER...
        ruby_block "Wait for all spark workers to finish installing, then start Spark Master" do
            block do         
                installed_count = "0"
                is_installed = "no"
                while installed_count.to_s != node['mapr']['node_count'].to_s do
                    node["mapr"]["cluster_nodes"].each do |nodeX|
			is_installed = "no"
                        while is_installed.to_s != "mapr-spark"  do
                            is_installed = /mapr-spark/.match(`ssh #{nodeX} yum list installed|grep mapr-spark[^-]`)
                            if is_installed.to_s == "mapr-spark"
                                installed_count = installed_count.to_i + 1
 				print "\nNode #{nodeX} has completed Spark Worker Installation"
                            else
                               `sleep 5` 
 			       print "\nWaiting on node #{nodeX}\n"
			    end
                        end
                    end 
                end
                print "\n\nAll #{node['mapr']['node_count']} nodes have finished installing Spark Workers...starting Spark Workers \n"
                `#{node['mapr']['home']}/spark/#{spark_home}/sbin/start-slaves.sh`    
            end
        end
    end       
end
