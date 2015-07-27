# The below specifies whether spark is standalone or uses yarn.  Acceptable values are 'yarn' and 'standalone'
default['mapr']['spark_type'] = 'yarn'

# NOTE: The below all REQUIRE FQDN's for their entries

# Acceptable values are "yes" and "no".  If "yes", installs spark workers on all nodes in the cluster
default['mapr']['install_spark'] = 'yes'

# The below only matters if the above is 'standalone'
default['mapr']['spark_master'] = 'ip-172-16-9-225.ec2.internal'
default['mapr']['spark_history'] = 'ip-172-16-9-225.ec2.internal'

default['mapr']['spark_installed'] = 'no'
