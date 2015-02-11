mapr_spark_installation  Cookbook
====================================
This cookbook installs the MapR Spark packages, and will integrate spark master and spark history server with the mapr warden if appropriate.

Requirements
------------
This cookbook requires the mapr_installation cookbook, located at https://github.com/GannettDigital/chef-mapr. 

Additionally, this cookbook a running MapR cluster, and assumes that the user used the mapr_installation cookbook to install the MapR cluster, and uses attributes from this cookbook to configure Spark.  If a different method was utilized, this cookbook *may* work as long as the attributes from mapr_installation are correct.


Attributes
----------

# The below specifies whether spark is standalone or uses yarn.  Acceptable values are 'yarn' and 'standalone'
default[:mapr][:spark_type] = "yarn"

#NOTE: The below all REQUIRE FQDN's for their entries

# Acceptable values are "yes" and "no".  If "yes", installs spark workers on all nodes in the cluster
default[:mapr][:install_spark] = "yes"

#The below only matters if the above is 'standalone'
default[:mapr][:spark_master] = "ip-172-16-9-225.ec2.internal"
default[:mapr][:spark_history] = "ip-172-16-9-225.ec2.internal"
e.g.


Usage
-----

Provided that the attributes from this cookbook and  mapr_installation are set, just include `mapr_spark_installation` in your node's `run_list`:

```json
{
  "name":"my_node",
  "run_list": [
    "recipe[mapr_spark_installation]"
  ]
}
```

Contributing
------------
TODO: (optional) If this is a public cookbook, detail the process for contributing. If this is a private cookbook, remove this section.

e.g.
1. Fork the repository on Github
2. Create a named feature branch (like `add_component_x`)
3. Write your change
4. Write tests for your change (if applicable)
5. Run the tests, ensuring they all pass
6. Submit a Pull Request using Github

License and Authors
-------------------
Authors: TODO: List authors
