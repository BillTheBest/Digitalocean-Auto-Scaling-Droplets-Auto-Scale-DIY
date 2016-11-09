# Digitalocean-Auto-Scaling-Droplets-Auto-Scale-DIY

a very simple solution. 
for every inexperienced user.
pure bash. easy to read easy to understand.
<br/>
works on CentOS 7


**create_droplet.sh** - place it on main droplet worker. creates new droplet automatically using DO API, checks for CPU load.<br/>
takes configuration file *droplet_config.sh* from (for example) private github repo ```DROPLET_CONFIG_FILE="LINK TO GITHUB PRIVATE REPO"``` injects it usin DO userdata into new droplet. 

**droplet_config.sh** - droplet configuration file, install packages, ssh keys, and files. takes configuration file *delete_droplet.sh* from (for example) private github repo. ```DELETE_DROPLET_SCRIPT="LINK TO GITHUB PRIVATE REPO"```

**delete_droplet.sh** - delete newly created droplet when load goes down, using DO API, checks for CPU load.

**lb_check_droplets.sh** - place it on load balancer. checks for ip address changes, reloads nginx.

**update_files.sh** - place it on main droplet worker. checks if new droplet was created, sync files.
