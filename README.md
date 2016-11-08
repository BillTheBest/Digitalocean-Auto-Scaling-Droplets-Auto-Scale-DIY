# Digitalocean-Auto-Scaling-Droplets-Auto-Scale-DIY

a very simple solution. 
for every inexperienced user.
pure bash. easy to read easy to understand.
<br/>
works on CentOS 7


**create_droplet.sh** - file to create new droplet automatically using DO API, checks for CPU load.<br/>
takes configuration file from (for example) private github repo ```DROPLET_CONFIG_FILE="LINK TO GITHUB PRIVATE REPO"```

**delete_droplet.sh** - file to delete droplet when load goes down.
